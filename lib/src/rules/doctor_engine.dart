import '../config/models/project_config.dart';
import '../graph/project_graph.dart';
import '../graph/schema.dart';
import '../inference/architecture_inference.dart';
import '../inference/naming_inference.dart';
import '../inference/state_management_detector.dart';
import 'findings.dart';

/// Compares observed vs declared truth and emits findings.
class DoctorEngine {
  DoctorReport analyze({
    required ProjectConfig config,
    required ProjectGraph graph,
    required StateManagementResult stateManagement,
    required ArchitectureInference architecture,
    required List<String> dioUsageInUi,
    List<String> httpUsageInUi = const [],
    List<String> screenDirectServiceAccess = const [],
    NamingInference? namingInference,
  }) {
    final findings = <DoctorFinding>[];
    final naming = namingInference ?? NamingInference();

    final declaredSm =
        config.stateManagement != 'auto' ? config.stateManagement : null;
    final observedSm = stateManagement.primary;

    String? interpretation;
    if (declaredSm != null &&
        observedSm != null &&
        declaredSm.toLowerCase() != observedSm.toLowerCase()) {
      interpretation =
          'The project appears to be migrating from $observedSm to ${_capitalize(declaredSm)}.';
      findings.add(
        DoctorFinding(
          severity: FindingSeverity.warning,
          message:
              'Declared state management ($declaredSm) differs from observed dominant pattern ($observedSm).',
          file: 'project',
          rule: 'state_management.declared_vs_observed',
          evidence: stateManagement.evidence,
          confidence: stateManagement.confidence,
          remediation:
              'Align flutter_ai_context.yaml with the codebase or finish the migration.',
        ),
      );
    }

    if (!_allowsDirectHttp(config.directHttpFromUi)) {
      for (final classId in dioUsageInUi) {
        final node = graph.findNode(classId);
        findings.add(
          DoctorFinding(
            severity: FindingSeverity.warning,
            message: 'Direct Dio usage detected in UI layer.',
            file: node?.file ?? classId,
            rule: 'direct_http_from_ui',
            evidence: [
              'creates Dio() in UI layer',
              if (architecture.dominantFlow != null)
                'Observed dominant pattern: ${architecture.dominantFlow}',
            ],
            confidence: 0.9,
            remediation:
                'Move the HTTP call to the feature service/provider flow.',
          ),
        );
      }

      for (final classId in httpUsageInUi) {
        final node = graph.findNode(classId);
        findings.add(
          DoctorFinding(
            severity: FindingSeverity.warning,
            message: 'Direct http.Client usage detected in UI layer.',
            file: node?.file ?? classId,
            rule: 'direct_http_from_ui',
            evidence: ['creates http.Client in UI layer'],
            confidence: 0.85,
            remediation:
                'Move network access behind a service or repository layer.',
          ),
        );
      }
    }

    for (final access in screenDirectServiceAccess) {
      final parts = access.split('->');
      if (parts.length != 2) continue;
      final screenNode = graph.findNode(parts[0]);
      final targetNode = graph.findNode(parts[1]);
      final screenFile = screenNode?.file ?? '';
      if (_isGeneratedOrTestPath(screenFile)) continue;
      if (targetNode != null && !_isDataLayerNode(targetNode.type)) continue;
      findings.add(
        DoctorFinding(
          severity: FindingSeverity.warning,
          message: 'Screen appears to call data layer directly.',
          file: screenNode?.file ?? parts[0],
          rule: 'screen_bypasses_state_management',
          evidence: [
            '${screenNode?.name ?? parts[0]} -> ${targetNode?.name ?? parts[1]}',
          ],
          confidence: 0.8,
          remediation:
              'Route screen actions through Provider, Bloc, or Riverpod notifier.',
        ),
      );
    }

    for (final forbidden in config.forbiddenStateManagement) {
      final count = stateManagement.distribution[forbidden] ?? 0;
      if (count > 0) {
        findings.add(
          DoctorFinding(
            severity: FindingSeverity.warning,
            message:
                '$forbidden is forbidden by declared rules but detected (${count.toStringAsFixed(0)}%).',
            file: 'project',
            rule: 'state_management.forbidden',
            evidence: stateManagement.evidence,
            confidence: stateManagement.confidence,
          ),
        );
      }
    }

    final conventions = naming.infer(graph);

    if (config.preferredScreenSuffix != null) {
      final screenConv =
          conventions.where((c) => c.role == 'screen').firstOrNull;
      if (screenConv != null &&
          screenConv.preferredPattern != config.preferredScreenSuffix &&
          screenConv.confidence < 0.9) {
        findings.add(
          DoctorFinding(
            severity: FindingSeverity.info,
            message:
                'Screen naming deviates from declared suffix ${config.preferredScreenSuffix}.',
            file: 'project',
            rule: 'naming.screen_suffix',
            evidence: ['Observed: ${screenConv.preferredPattern}'],
            confidence: screenConv.confidence,
          ),
        );
      }
    }

    if (config.preferredProviderSuffix != null) {
      final providerConv =
          conventions.where((c) => c.role == 'provider').firstOrNull;
      if (providerConv != null &&
          providerConv.preferredPattern != config.preferredProviderSuffix &&
          providerConv.confidence < 0.9) {
        findings.add(
          DoctorFinding(
            severity: FindingSeverity.info,
            message:
                'Provider naming deviates from declared suffix ${config.preferredProviderSuffix}.',
            file: 'project',
            rule: 'naming.provider_suffix',
            evidence: ['Observed: ${providerConv.preferredPattern}'],
            confidence: providerConv.confidence,
          ),
        );
      }
    }

    for (final feature in graph.nodesByType(NodeType.feature)) {
      final members = graph
          .edgesFrom(feature.id)
          .where((e) => e.type == EdgeType.contains)
          .map((e) => graph.findNode(e.to))
          .whereType();
      final hasScreen = members.any((m) => m.type == NodeType.screen);
      if (!hasScreen) {
        findings.add(
          DoctorFinding(
            severity: FindingSeverity.info,
            message: 'Feature "${feature.name}" has no detected screen.',
            file: 'project',
            rule: 'feature.missing_screen',
            evidence: ['Feature cluster without screen node'],
            confidence: 0.75,
            remediation:
                'Add a screen widget or verify feature clustering for this module.',
          ),
        );
      }
    }

    if (config.routing != 'auto') {
      final routeTypes = graph
          .nodesByType(NodeType.route)
          .map((r) => r.metadata['routeType'] as String? ?? 'unknown')
          .toSet();
      final expected = _expectedRouteTypes(config.routing);
      if (routeTypes.isNotEmpty &&
          expected.isNotEmpty &&
          routeTypes.intersection(expected).isEmpty) {
        findings.add(
          DoctorFinding(
            severity: FindingSeverity.info,
            message:
                'Declared routing (${config.routing}) does not match detected route types ($routeTypes).',
            file: 'project',
            rule: 'routing.declared_vs_observed',
            evidence: routeTypes.toList(),
            confidence: 0.7,
          ),
        );
      }
    }

    final dimensions = <String, int>{
      'Architecture': _scoreArchitecture(findings, architecture.confidence),
      'Dependencies': 100,
      'Naming': _scoreNaming(findings),
      'Routes': _scoreRoutes(findings, graph),
      'Feature Mapping': _scoreFeatures(graph, findings),
      'Context Freshness': 100,
    };

    final overall =
        dimensions.values.fold<int>(0, (a, b) => a + b) ~/ dimensions.length;

    return DoctorReport(
      findings: findings,
      readinessScore: overall,
      dimensions: dimensions,
      declaredArchitecture: declaredSm != null ? _capitalize(declaredSm) : null,
      observedArchitecture: observedSm,
      interpretation: interpretation,
    );
  }

  bool _allowsDirectHttp(String rule) =>
      rule == 'true' || rule == 'allow' || rule == 'allowed';

  Set<String> _expectedRouteTypes(String routing) {
    switch (routing.toLowerCase()) {
      case 'go_router':
      case 'gorouter':
        return {'go_router'};
      case 'auto_route':
      case 'autoroute':
        return {'auto_route'};
      case 'navigator':
        return {'navigator'};
      default:
        return {};
    }
  }

  int _scoreArchitecture(List<DoctorFinding> findings, double confidence) {
    final archFindings = findings
        .where((f) =>
            f.rule?.startsWith('direct_http') == true ||
            f.rule == 'screen_bypasses_state_management')
        .length;
    final base = (confidence * 100).round();
    return (base - archFindings * 10).clamp(0, 100);
  }

  int _scoreNaming(List<DoctorFinding> findings) {
    final namingFindings =
        findings.where((f) => f.rule?.startsWith('naming') == true).length;
    return (100 - namingFindings * 5).clamp(0, 100);
  }

  int _scoreRoutes(List<DoctorFinding> findings, ProjectGraph graph) {
    final routeCount = graph.nodesByType(NodeType.route).length;
    if (routeCount == 0) return 60;
    final routingFindings =
        findings.where((f) => f.rule?.startsWith('routing') == true).length;
    return (88 - routingFindings * 8).clamp(0, 100);
  }

  int _scoreFeatures(ProjectGraph graph, List<DoctorFinding> findings) {
    final features = graph.nodesByType(NodeType.feature).length;
    final missingScreen = findings
        .where((f) => f.rule == 'feature.missing_screen')
        .length;
    if (features == 0) return 50;
    if (features < 3) return (70 - missingScreen * 5).clamp(0, 100);
    return (88 - missingScreen * 5).clamp(0, 100);
  }

  String _capitalize(String input) =>
      input.isEmpty ? input : input[0].toUpperCase() + input.substring(1);

  bool _isGeneratedOrTestPath(String file) {
    return file.contains('/test/') ||
        file.contains('.g.dart') ||
        file.contains('.freezed.dart') ||
        file.contains('/generated/');
  }

  bool _isDataLayerNode(NodeType type) {
    return type == NodeType.service ||
        type == NodeType.repository ||
        type == NodeType.apiClient;
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
