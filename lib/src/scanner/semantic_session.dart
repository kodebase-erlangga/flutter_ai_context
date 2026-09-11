import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;

import '../shared/logger.dart';

/// Wraps [AnalysisContextCollection] with parse-once caching and lazy resolution.
class SemanticSession {
  SemanticSession({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;
  final Map<String, CompilationUnit> _parsedUnits = {};
  final Map<String, ResolvedUnitResult> _resolvedUnits = {};
  AnalysisContextCollection? _collection;
  String? _projectRoot;

  /// Prepares semantic context without resolving every file upfront.
  Future<void> load(String projectRoot) async {
    _parsedUnits.clear();
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

  /// Reads and parses a Dart file once, caching the AST.
  CompilationUnit readUnit(String absolutePath) {
    final normalized = p.normalize(absolutePath);
    final cached = _parsedUnits[normalized];
    if (cached != null) return cached;

    final content = File(normalized).readAsStringSync();
    final unit = parseString(content: content, path: normalized).unit;
    _parsedUnits[normalized] = unit;
    return unit;
  }

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
          _parsedUnits[normalized] = result.unit;
          return;
        }
      } catch (e) {
        _logger.debug('Could not resolve $normalized: $e');
      }
    }
  }

  /// Resolves [paths] with bounded concurrency.
  Future<void> ensureResolvedBatch(
    List<String> absolutePaths, {
    int concurrency = 8,
  }) async {
    if (absolutePaths.isEmpty || _collection == null) return;

    for (var index = 0; index < absolutePaths.length; index += concurrency) {
      final batch = absolutePaths
          .skip(index)
          .take(concurrency)
          .where((path) => !_resolvedUnits.containsKey(p.normalize(path)))
          .toList();
      if (batch.isEmpty) continue;
      await Future.wait(batch.map(ensureResolved));
    }
  }

  /// Returns compilation unit with semantic info when available.
  CompilationUnit getUnit(String absolutePath, [String? content]) {
    final normalized = p.normalize(absolutePath);
    final resolved = _resolvedUnits[normalized];
    if (resolved != null) return resolved.unit;

    final parsed = _parsedUnits[normalized];
    if (parsed != null) return parsed;

    if (content != null) {
      final unit = parseString(content: content, path: normalized).unit;
      _parsedUnits[normalized] = unit;
      return unit;
    }

    return readUnit(normalized);
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
      final name = supertype.element.displayName;
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
      return target.constructorName.type.name.lexeme;
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
    return node.constructorName.type.name.lexeme;
  }

  /// Resolves constructor calls written as `Type()`.
  String? resolveConstructorCall(MethodInvocation node) {
    if (node.target != null) return null;
    final name = node.methodName.name;
    if (_looksLikeTypeName(name)) return name;
    return null;
  }

  /// Index of class simple names to file paths using the parse cache.
  Map<String, List<String>> buildClassIndex(
    String projectRoot,
    List<String> dartFiles,
  ) {
    final index = <String, List<String>>{};
    for (final relative in dartFiles) {
      final absolute = p.join(projectRoot, relative);
      if (!File(absolute).existsSync()) continue;
      final unit = readUnit(absolute);
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

/// Heuristic for whether a file benefits from semantic resolution.
bool needsSemanticResolution(String relativePath, CompilationUnit unit) {
  final path = relativePath.toLowerCase();
  if (_isSemanticSkipPath(path)) return false;
  if (!_unitNeedsSemanticAnalysis(unit)) return false;

  if (path.contains('_screen') ||
      path.contains('_page') ||
      path.contains('/screens/') ||
      path.contains('/pages/') ||
      path.contains('/presentation/') ||
      path.contains('_provider') ||
      path.contains('_controller') ||
      path.contains('/controllers/') ||
      path.contains('_binding') ||
      path.contains('/bindings/') ||
      path.contains('_bloc') ||
      path.contains('_cubit') ||
      path.contains('_service') ||
      path.contains('_repository') ||
      path.contains('/services/') ||
      path.contains('/data/') ||
      path.contains('route') ||
      path.contains('router')) {
    return true;
  }

  for (final decl in unit.declarations) {
    if (decl is! ClassDeclaration) continue;
    final name = decl.name.lexeme;
    if (name.endsWith('Screen') ||
        name.endsWith('Page') ||
        name.endsWith('Controller') ||
        name.endsWith('Provider') ||
        name.endsWith('Bloc') ||
        name.endsWith('Cubit') ||
        name.endsWith('Binding') ||
        name.endsWith('Service') ||
        name.endsWith('Repository')) {
      return true;
    }
  }

  return false;
}

bool _isSemanticSkipPath(String path) {
  return path.contains('/test/') ||
      path.endsWith('.g.dart') ||
      path.endsWith('.freezed.dart') ||
      path.contains('/generated/') ||
      path.contains('/constants/') ||
      path.contains('/extensions/') ||
      path.contains('/theme/') ||
      path.endsWith('_strings.dart') ||
      path.contains('/l10n/') ||
      (path.contains('/domain/') && path.endsWith('_model.dart')) ||
      (path.contains('/models/') &&
          path.endsWith('_model.dart') &&
          !path.contains('repository'));
}

bool _unitNeedsSemanticAnalysis(CompilationUnit unit) {
  final visitor = _SemanticNeedVisitor();
  unit.accept(visitor);
  return visitor.needed;
}

class _SemanticNeedVisitor extends RecursiveAstVisitor<void> {
  bool needed = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    needed = true;
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    needed = true;
    super.visitInstanceCreationExpression(node);
  }
}
