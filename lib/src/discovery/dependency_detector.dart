import 'package:yaml/yaml.dart';

/// Categories for pubspec dependencies.
enum DependencyCategory {
  stateManagement,
  networking,
  routing,
  persistence,
  dependencyInjection,
  serialization,
  codeGeneration,
  testing,
  analytics,
  firebase,
  localization,
  platform,
  other,
}

/// Detected dependency with category.
class DetectedDependency {
  const DetectedDependency({
    required this.name,
    required this.category,
    this.version,
  });

  final String name;
  final DependencyCategory category;
  final String? version;
}

/// Parses pubspec.yaml and classifies dependencies.
class DependencyDetector {
  static const _categories = {
    'provider': DependencyCategory.stateManagement,
    'flutter_riverpod': DependencyCategory.stateManagement,
    'riverpod': DependencyCategory.stateManagement,
    'hooks_riverpod': DependencyCategory.stateManagement,
    'flutter_bloc': DependencyCategory.stateManagement,
    'bloc': DependencyCategory.stateManagement,
    'get': DependencyCategory.stateManagement,
    'getx': DependencyCategory.stateManagement,
    'dio': DependencyCategory.networking,
    'http': DependencyCategory.networking,
    'retrofit': DependencyCategory.networking,
    'go_router': DependencyCategory.routing,
    'auto_route': DependencyCategory.routing,
    'shared_preferences': DependencyCategory.persistence,
    'hive': DependencyCategory.persistence,
    'sqflite': DependencyCategory.persistence,
    'get_it': DependencyCategory.dependencyInjection,
    'injectable': DependencyCategory.dependencyInjection,
    'json_annotation': DependencyCategory.serialization,
    'freezed_annotation': DependencyCategory.serialization,
    'json_serializable': DependencyCategory.codeGeneration,
    'build_runner': DependencyCategory.codeGeneration,
    'flutter_test': DependencyCategory.testing,
    'mockito': DependencyCategory.testing,
    'firebase_core': DependencyCategory.firebase,
    'firebase_auth': DependencyCategory.firebase,
    'firebase_analytics': DependencyCategory.analytics,
    'intl': DependencyCategory.localization,
  };

  List<DetectedDependency> detect(String pubspecContent) {
    final yaml = loadYaml(pubspecContent);
    if (yaml is! Map) return [];

    final deps = <DetectedDependency>[];
    for (final section in ['dependencies', 'dev_dependencies']) {
      final sectionMap = yaml[section];
      if (sectionMap is! Map) continue;
      for (final entry in sectionMap.entries) {
        final name = entry.key.toString();
        final version = entry.value?.toString();
        deps.add(
          DetectedDependency(
            name: name,
            category: _categories[name] ?? DependencyCategory.other,
            version: version,
          ),
        );
      }
    }
    return deps;
  }

  List<String> stateManagementCandidates(List<DetectedDependency> deps) {
    const smPackages = {
      'provider',
      'flutter_riverpod',
      'riverpod',
      'hooks_riverpod',
      'flutter_bloc',
      'bloc',
      'get',
    };
    return deps
        .where((d) => smPackages.contains(d.name))
        .map((d) => _friendlyName(d.name))
        .toList();
  }

  String? detectNetworking(List<DetectedDependency> deps) {
    for (final d in deps) {
      if (d.category == DependencyCategory.networking) {
        return _friendlyName(d.name);
      }
    }
    return null;
  }

  String? detectRouting(List<DetectedDependency> deps) {
    for (final d in deps) {
      if (d.category == DependencyCategory.routing) {
        return _friendlyName(d.name);
      }
    }
    return null;
  }

  String _friendlyName(String package) {
    switch (package) {
      case 'flutter_riverpod':
      case 'hooks_riverpod':
        return 'Riverpod';
      case 'flutter_bloc':
        return 'Bloc';
      case 'go_router':
        return 'GoRouter';
      case 'auto_route':
        return 'AutoRoute';
      default:
        if (package.isEmpty) return package;
        return package[0].toUpperCase() + package.substring(1);
    }
  }
}
