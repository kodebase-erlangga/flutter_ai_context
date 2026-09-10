import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;

import '../shared/logger.dart';

/// Wraps [AnalysisContextCollection] with parse fallback.
class SemanticSession {
  SemanticSession({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;
  final Map<String, ResolvedUnitResult> _resolvedUnits = {};
  bool _collectionLoaded = false;

  /// Loads semantic context for the project root.
  Future<void> load(String projectRoot) async {
    _resolvedUnits.clear();
    _collectionLoaded = false;

    try {
      final collection = AnalysisContextCollection(
        includedPaths: [p.normalize(projectRoot)],
        resourceProvider: PhysicalResourceProvider.INSTANCE,
      );

      for (final context in collection.contexts) {
        for (final path in context.contextRoot.analyzedFiles()) {
          if (!path.endsWith('.dart')) continue;
          try {
            final result = await context.currentSession.getResolvedUnit(path);
            if (result is ResolvedUnitResult) {
              _resolvedUnits[p.normalize(path)] = result;
            }
          } catch (e) {
            _logger.debug('Could not resolve $path: $e');
          }
        }
      }
      _collectionLoaded = true;
      _logger.debug(
        'Semantic session loaded ${_resolvedUnits.length} resolved units',
      );
    } catch (e) {
      _logger.debug('AnalysisContextCollection unavailable: $e');
    }
  }

  bool get hasCollection => _collectionLoaded && _resolvedUnits.isNotEmpty;

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
