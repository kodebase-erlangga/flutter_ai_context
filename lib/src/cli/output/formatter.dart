import '../../inference/architecture_inference.dart';
import '../../inference/state_management_detector.dart';
import '../../rules/findings.dart';

/// Formats CLI output for commands.
class OutputFormatter {
  static String initSummary({
    required String projectName,
    required StateManagementResult stateManagement,
    required String? networking,
    required String? routing,
    required String? architectureStyle,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Detected:');
    buffer.writeln(
      'State Management : ${stateManagement.primary ?? 'Unknown'}',
    );
    buffer.writeln('Networking       : ${networking ?? 'Unknown'}');
    buffer.writeln('Routing          : ${routing ?? 'Unknown'}');
    buffer.writeln('Architecture     : ${architectureStyle ?? 'Unknown'}');
    buffer.writeln('Testing          : flutter_test');
    return buffer.toString();
  }

  static String scanSummary({
    required int filesAnalyzed,
    required int relationships,
    required int features,
    required ArchitectureInference architecture,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('✓ Project discovered');
    buffer.writeln('✓ $filesAnalyzed Dart files indexed');
    buffer.writeln('✓ $relationships semantic relationships resolved');
    buffer.writeln('✓ $features features identified');
    buffer.writeln('✓ Architecture inferred');
    buffer.writeln('✓ Context generated');
    if (architecture.dominantFlow != null) {
      buffer.writeln();
      buffer.writeln('Dominant flow: ${architecture.dominantFlow}');
    }
    return buffer.toString();
  }

  static String doctorReport(DoctorReport report) {
    final buffer = StringBuffer();
    buffer.writeln('Flutter AI Context Doctor');
    buffer.writeln();
    buffer.writeln('Architecture');

    if (report.declaredArchitecture != null) {
      buffer.writeln('Declared: ${report.declaredArchitecture}');
    }
    if (report.observedArchitecture != null) {
      buffer.writeln('Observed: ${report.observedArchitecture}');
    }
    if (report.interpretation != null) {
      buffer.writeln();
      buffer.writeln('Interpretation:');
      buffer.writeln(report.interpretation);
    }

    buffer.writeln();
    if (report.findings.isEmpty) {
      buffer.writeln('✓ No issues detected');
    } else {
      final warnings = report.findings
          .where((f) => f.severity == FindingSeverity.warning)
          .toList();
      final infos = report.findings
          .where((f) => f.severity == FindingSeverity.info)
          .toList();

      if (warnings.isNotEmpty) {
        buffer.writeln('Warnings');
        buffer.writeln();
        for (final finding in warnings) {
          buffer.writeln('⚠ ${finding.file}');
          buffer.writeln('  ${finding.message}');
          if (finding.remediation != null) {
            buffer.writeln('  Suggested action: ${finding.remediation}');
          }
          buffer.writeln();
        }
      }

      if (infos.isNotEmpty) {
        buffer.writeln('Info');
        buffer.writeln();
        for (final finding in infos) {
          buffer.writeln('ℹ ${finding.file}');
          buffer.writeln('  ${finding.message}');
          if (finding.remediation != null) {
            buffer.writeln('  Note: ${finding.remediation}');
          }
          buffer.writeln();
        }
      }
    }

    buffer.writeln('AI Readiness Score: ${report.readinessScore}/100');
    return buffer.toString();
  }
}
