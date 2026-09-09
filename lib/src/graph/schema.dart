/// Graph schema version for cache compatibility.
const int graphSchemaVersion = 1;

/// Node types in the project knowledge graph.
enum NodeType {
  project,
  package,
  feature,
  file,
  classNode,
  function,
  screen,
  widget,
  provider,
  bloc,
  cubit,
  notifier,
  service,
  repository,
  apiClient,
  model,
  entity,
  route,
  test,
  unknown,
}

extension NodeTypeX on NodeType {
  String get wireName {
    switch (this) {
      case NodeType.classNode:
        return 'class';
      default:
        return name;
    }
  }

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
  contains,
  imports,
  dependsOn,
  calls,
  extendsType,
  implementsType,
  watches,
  reads,
  navigatesTo,
  usesService,
  usesModel,
  belongsToFeature,
  mapsToRoute,
  tests,
}

extension EdgeTypeX on EdgeType {
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
