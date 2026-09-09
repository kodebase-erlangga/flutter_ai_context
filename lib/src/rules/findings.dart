/// Severity levels for doctor findings.
enum FindingSeverity { info, warning, error }

/// A single doctor finding.
class DoctorFinding {
  DoctorFinding({
    required this.severity,
    required this.message,
    required this.file,
    this.rule,
    this.evidence = const [],
    this.confidence = 1.0,
    this.remediation,
  });

  final FindingSeverity severity;
  final String message;
  final String file;
  final String? rule;
  final List<String> evidence;
  final double confidence;
  final String? remediation;
}

/// Doctor report with AI readiness score.
class DoctorReport {
  DoctorReport({
    required this.findings,
    required this.readinessScore,
    required this.dimensions,
    this.declaredArchitecture,
    this.observedArchitecture,
    this.interpretation,
  });

  final List<DoctorFinding> findings;
  final int readinessScore;
  final Map<String, int> dimensions;
  final String? declaredArchitecture;
  final String? observedArchitecture;
  final String? interpretation;
}
