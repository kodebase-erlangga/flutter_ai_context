/// Graph schema version for cache compatibility.
const int graphSchemaVersion = 1;

/// Node types in the project knowledge graph.
enum NodeType {
  /// Root project node.
  project,

  /// Dart package dependency.
  package,

  /// Feature module grouping.
  feature,

  /// Source file.
  file,

  /// Dart class.
  classNode,

  /// Top-level or named function.
  function,

  /// Screen / page widget.
  screen,

  /// Reusable widget.
  widget,

  /// State-management provider.
  provider,

  /// Bloc state container.
  bloc,

  /// Cubit state container.
  cubit,

  /// Riverpod / ChangeNotifier.
  notifier,

  /// Service layer class.
  service,

  /// Repository / data access class.
  repository,

  /// HTTP / API client.
  apiClient,

  /// Data model / DTO.
  model,

  /// Domain entity.
  entity,

  /// Navigation route.
  route,

  /// Test file or suite.
  test,

  /// Unclassified node.
  unknown,
}

/// Serialization helpers for [NodeType].
extension NodeTypeX on NodeType {
  /// Wire-format name used in JSON graph files.
  String get wireName {
    switch (this) {
      case NodeType.classNode:
        return 'class';
      default:
        return name;
    }
  }

  /// Parses a wire-format name back to a [NodeType].
  static NodeType fromWire(String value) {
    if (value == 'class') return NodeType.classNode;
    return NodeType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NodeType.unknown,
    );
  }
}

/// Edge types between graph nodes.
enum EdgeType {
  /// Parent contains child (e.g. feature contains file).
  contains,

  /// Dart import relationship.
  imports,

  /// Runtime or architectural dependency.
  dependsOn,

  /// Function or method call.
  calls,

  /// Class extends another type.
  extendsType,

  /// Class implements another type.
  implementsType,

  /// Reactive watch (e.g. Riverpod watch).
  watches,

  /// Reactive read (e.g. Riverpod read).
  reads,

  /// Navigation from one screen to another.
  navigatesTo,

  /// UI or provider uses a service.
  usesService,

  /// Class references a data model.
  usesModel,

  /// File or class belongs to a feature.
  belongsToFeature,

  /// Screen maps to a route definition.
  mapsToRoute,

  /// Test covers a production symbol.
  tests,
}

/// Serialization helpers for [EdgeType].
extension EdgeTypeX on EdgeType {
  /// Wire-format name used in JSON graph files.
  String get wireName {
    switch (this) {
      case EdgeType.extendsType:
        return 'extends';
      case EdgeType.implementsType:
        return 'implements';
      default:
        return name.replaceAllMapped(
          RegExp(r'[A-Z]'),
          (m) => '_${m.group(0)!.toLowerCase()}',
        );
    }
  }

  /// Parses a wire-format name back to an [EdgeType].
  static EdgeType fromWire(String value) {
    switch (value) {
      case 'extends':
        return EdgeType.extendsType;
      case 'implements':
        return EdgeType.implementsType;
      default:
        return EdgeType.values.firstWhere(
          (e) => e.wireName == value,
          orElse: () => EdgeType.dependsOn,
        );
    }
  }
}
