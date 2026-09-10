import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;

import '../shared/logger.dart';

/// Wraps [AnalysisContextCollection] with lazy per-file resolution.
class SemanticSession {
  SemanticSession({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;
  final Map<String, ResolvedUnitResult> _resolvedUnits = {};
  AnalysisContextCollection? _collection;
  String? _projectRoot;

  /// Prepares semantic context without resolving every file upfront.
  Future<void> load(String projectRoot) async {
    _resolvedUnits.clear();
    _projectRoot = p.normalize(projectRoot);
    _collection = null;

    try {
      _collection = AnalysisContextCollection(
        includedPaths: [_projectRoot!],
        resourceProvider: PhysicalResourceProvider.INSTANCE,
      );
      _logger.debug('Semantic session initialized (lazy resolution enabled)');
    } catch (e) {
      _logger.debug('AnalysisContextCollection unavailable: $e');
    }
  }

  bool get hasCollection => _collection != null;

  /// Lazily resolves a single Dart unit when semantic context is available.
  Future<void> ensureResolved(String absolutePath) async {
    final normalized = p.normalize(absolutePath);
    if (_resolvedUnits.containsKey(normalized) || _collection == null) {
      return;
    }

    for (final context in _collection!.contexts) {
      try {
        final result = await context.currentSession.getResolvedUnit(normalized);
        if (result is ResolvedUnitResult) {
          _resolvedUnits[normalized] = result;
          return;
        }
      } catch (e) {
        _logger.debug('Could not resolve $normalized: $e');
      }
    }
  }

  /// Returns compilation unit with semantic info when available.
  CompilationUnit getUnit(String absolutePath, String content) {
    final normalized = p.normalize(absolutePath);
    final resolved = _resolvedUnits[normalized];
    if (resolved != null) return resolved.unit;
    return parseString(content: content, path: normalized).unit;
  }

  /// Whether this file was semantically resolved.
  bool isSemanticallyResolved(String absolutePath) {
    return _resolvedUnits.containsKey(p.normalize(absolutePath));
  }

  /// Resolves supertype name using element model when possible.
  String? resolveSuperType(ClassDeclaration node) {
    final astSuper = node.extendsClause?.superclass.toString();
    final fromFragment = _resolveSuperTypeFromFragment(node);
    if (fromFragment != null) return fromFragment;

    try {
      // ignore: deprecated_member_use
      final element = node.declaredElement;
      if (element != null) {
        // ignore: deprecated_member_use
        final supertype = element.supertype;
        if (supertype != null) {
          // ignore: deprecated_member_use
          final superElement = supertype.element.displayName;
          if (superElement.isNotEmpty && superElement != 'Object') {
            return superElement;
          }
        }
      }
    } catch (_) {
      // Fall back to AST when element model is unavailable.
    }
    return astSuper;
  }

  String? _resolveSuperTypeFromFragment(ClassDeclaration node) {
    try {
      // ignore: experimental_member_use
      final fragment = node.declaredFragment;
      if (fragment == null) return null;
      // ignore: experimental_member_use
      final element = fragment.element;
      // ignore: experimental_member_use
      final supertype = element.supertype;
      if (supertype == null) return null;
      // ignore: experimental_member_use
      final name = supertype.element3.displayName;
      if (name.isNotEmpty && name != 'Object') return name;
    } catch (_) {
      // Fragment API unavailable in this analyzer context.
    }
    return null;
  }

  /// Resolves invoked method target using semantics with AST fallback.
  String? resolveInvocationTarget(MethodInvocation node) {
    try {
      // ignore: experimental_member_use
      final element = node.methodName.element;
      final elementName = element?.displayName;
      if (elementName != null &&
          elementName.isNotEmpty &&
          node.target == null &&
          _looksLikeTypeName(elementName)) {
        return elementName;
      }
    } catch (_) {
      // Ignore and use AST fallback below.
    }

    final target = node.target;
    if (target is SimpleIdentifier) return target.name;
    if (target is PrefixedIdentifier) return target.identifier.name;
    if (target is InstanceCreationExpression) {
      return target.constructorName.type.name2.lexeme;
    }
    return target?.toString();
  }

  /// Resolves constructed type name.
  String? resolveConstructedType(InstanceCreationExpression node) {
    try {
      // ignore: experimental_member_use
      final element = node.constructorName.element;
      final typeName = element?.displayName;
      if (typeName != null && typeName.isNotEmpty) return typeName;
    } catch (_) {
      // Fall back to AST type name.
    }
    return node.constructorName.type.name2.lexeme;
  }

  /// Resolves constructor calls written as `Type()`.
  String? resolveConstructorCall(MethodInvocation node) {
    if (node.target != null) return null;
    final name = node.methodName.name;
    if (_looksLikeTypeName(name)) return name;
    return null;
  }

  /// Index of class simple names to file paths.
  Map<String, List<String>> buildClassIndex(
    String projectRoot,
    List<String> dartFiles,
  ) {
    final index = <String, List<String>>{};
    for (final relative in dartFiles) {
      final absolute = p.join(projectRoot, relative);
      if (!File(absolute).existsSync()) continue;
      final content = File(absolute).readAsStringSync();
      final unit = getUnit(absolute, content);
      for (final decl in unit.declarations) {
        if (decl is ClassDeclaration) {
          index.putIfAbsent(decl.name.lexeme, () => []).add(relative);
        }
      }
    }
    return index;
  }

  bool _looksLikeTypeName(String name) {
    if (name.isEmpty) return false;
    final first = name[0];
    return first == first.toUpperCase();
  }
}
