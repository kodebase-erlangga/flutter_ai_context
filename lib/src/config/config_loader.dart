import 'dart:io';

import 'package:yaml/yaml.dart';

import 'models/project_config.dart';

/// Loads and validates flutter_ai_context.yaml.
class ConfigLoader {
  ProjectConfig load(String configPath) {
    final file = File(configPath);
    if (!file.existsSync()) {
      throw ConfigException(
        'Configuration file not found: $configPath\n'
        'Run `flutter_ai_context init` to create one.',
      );
    }

    try {
      final content = file.readAsStringSync();
      final yaml = loadYaml(content);
      if (yaml is! Map) {
        throw ConfigException('Invalid configuration: root must be a map.');
      }
      return ProjectConfig.fromYamlMap(yaml);
    } on YamlException catch (e) {
      throw ConfigException('Malformed flutter_ai_context.yaml: ${e.message}');
    }
  }

  void writeDefault(String configPath, ProjectConfig config) {
    final buffer = StringBuffer();
    buffer.writeln('# flutter_ai_context configuration');
    buffer.writeln('# Run `flutter_ai_context scan` to analyze your project.');
    buffer.writeln();
    _writeYamlMap(buffer, config.toYamlMap(), 0);
    File(configPath).writeAsStringSync(buffer.toString());
  }

  void _writeYamlMap(
      StringBuffer buffer, Map<String, dynamic> map, int indent) {
    final pad = '  ' * indent;
    for (final entry in map.entries) {
      final value = entry.value;
      if (value is Map) {
        buffer.writeln('$pad${entry.key}:');
        _writeYamlMap(
          buffer,
          value.map((k, v) => MapEntry(k.toString(), v)),
          indent + 1,
        );
      } else if (value is List) {
        buffer.writeln('$pad${entry.key}:');
        for (final item in value) {
          buffer.writeln('$pad  - ${_yamlScalar(item)}');
        }
      } else {
        buffer.writeln('$pad${entry.key}: ${_yamlScalar(value)}');
      }
    }
  }

  String _yamlScalar(dynamic value) {
    if (value is bool || value is num) return value.toString();
    final text = value.toString();
    final needsQuotes = text.contains('*') ||
        text.contains('&') ||
        text.contains('!') ||
        text.contains('#') ||
        text.contains(':') ||
        text.contains('"') ||
        text.startsWith('[') ||
        text.startsWith('{');
    if (needsQuotes) return "'$text'";
    return text;
  }
}

class ConfigException implements Exception {
  ConfigException(this.message);
  final String message;

  @override
  String toString() => message;
}
