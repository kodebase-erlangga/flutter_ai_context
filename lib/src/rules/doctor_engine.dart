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
    }

    if (config.directHttpFromUi != 'true') {
      for (final classId in dioUsageInUi) {
        final node = graph.findNode(classId);
        findings.add(
          DoctorFinding(
            severity: FindingSeverity.warning,
            message: 'Direct Dio usage detected.',
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

    if (config.preferredScreenSuffix != null) {
      final conventions = naming.infer(graph);
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

    final dimensions = <String, int>{
      'Architecture': _scoreArchitecture(findings, architecture.confidence),
      'Dependencies': 100,
      'Naming': _scoreNaming(findings),
      'Routes': 85,
      'Feature Mapping': _scoreFeatures(graph),
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

  int _scoreArchitecture(List<DoctorFinding> findings, double confidence) {
    final archFindings =
        findings.where((f) => f.rule?.startsWith('direct_http') == true).length;
    final base = (confidence * 100).round();
    return (base - archFindings * 10).clamp(0, 100);
  }

  int _scoreNaming(List<DoctorFinding> findings) {
    final namingFindings =
        findings.where((f) => f.rule?.startsWith('naming') == true).length;
    return (100 - namingFindings * 5).clamp(0, 100);
  }

  int _scoreFeatures(ProjectGraph graph) {
    final features = graph.nodesByType(NodeType.feature).length;
    if (features == 0) return 50;
    if (features < 3) return 70;
    return 88;
  }

  String _capitalize(String input) =>
      input.isEmpty ? input : input[0].toUpperCase() + input.substring(1);
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
