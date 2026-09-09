import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../config/models/project_config.dart';
import '../shared/utils.dart';
import 'dependency_detector.dart';

/// Result of initial project discovery.
class DiscoveryResult {
  DiscoveryResult({
    required this.root,
    required this.projectName,
    required this.isFlutter,
    required this.dartFiles,
    required this.dependencies,
    this.stateManagementCandidates = const [],
    this.networking,
    this.routing,
    this.architectureStyle,
  });

  final String root;
  final String projectName;
  final bool isFlutter;
  final List<String> dartFiles;
  final List<DetectedDependency> dependencies;
  final List<String> stateManagementCandidates;
  final String? networking;
  final String? routing;
  final String? architectureStyle;
}

/// Discovers project structure and metadata.
class ProjectDiscovery {
  ProjectDiscovery({DependencyDetector? detector})
      : _detector = detector ?? DependencyDetector();

  final DependencyDetector _detector;

  DiscoveryResult discover(String root, ProjectConfig config) {
    if (!Utils.isDartProject(root)) {
      throw DiscoveryException(
        'Not a Dart/Flutter project.\n'
        'Run this command from a directory containing pubspec.yaml.',
      );
    }

    final pubspecPath = p.join(root, 'pubspec.yaml');
    final pubspecContent = File(pubspecPath).readAsStringSync();
    final yaml = loadYaml(pubspecContent) as Map;
    final projectName = yaml['name']?.toString() ?? p.basename(root);

    final deps = _detector.detect(pubspecContent);
    final dartFiles = Utils.findDartFiles(
      root,
      config.scanPaths,
      config.ignorePatterns,
    );

    return DiscoveryResult(
      root: root,
      projectName: projectName,
      isFlutter: Utils.isFlutterProject(root),
      dartFiles: dartFiles,
      dependencies: deps,
      stateManagementCandidates: _detector.stateManagementCandidates(deps),
      networking: _detector.detectNetworking(deps),
      routing: _detector.detectRouting(deps),
      architectureStyle: _inferArchitectureStyle(dartFiles),
    );
  }

  String? _inferArchitectureStyle(List<String> files) {
    final featureFirst = files.where((f) => f.contains('features/')).length;
    final layerFirst = files.where((f) {
      return f.contains('screens/') ||
          f.contains('providers/') ||
          f.contains('services/');
    }).length;

    if (featureFirst > layerFirst && featureFirst > 0) {
      return 'Feature-based';
    }
    if (layerFirst > 0) return 'Layer-based';
    return null;
  }
}

class DiscoveryException implements Exception {
  DiscoveryException(this.message);
  final String message;

  @override
  String toString() => message;
}
