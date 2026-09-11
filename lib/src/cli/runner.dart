import 'dart:io';

import 'package:args/args.dart';
import '../shared/logger.dart';
import 'commands/context_command.dart';
import 'commands/doctor_command.dart';
import 'commands/init_command.dart';
import 'commands/scan_command.dart';
import 'commands/status_command.dart';
import 'commands/sync_command.dart';

/// CLI version.
const cliVersion = '0.5.2';

/// Main CLI runner.
class CliRunner {
  CliRunner({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  ArgParser buildParser() {
    return ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false, help: 'Print usage.')
      ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Verbose output.')
      ..addFlag('quiet', abbr: 'q', negatable: false, help: 'Quiet output.')
      ..addFlag('version', negatable: false, help: 'Print version.')
      ..addCommand('init', ArgParser()..addFlag('help', negatable: false))
      ..addCommand('scan', ArgParser()..addFlag('help', negatable: false))
      ..addCommand('sync', ArgParser()..addFlag('help', negatable: false))
      ..addCommand('status', ArgParser()..addFlag('help', negatable: false))
      ..addCommand('doctor', ArgParser()..addFlag('help', negatable: false))
      ..addCommand(
        'context',
        ArgParser()
          ..addFlag('help', negatable: false)
          ..addFlag('list', negatable: false, help: 'List available scopes.')
          ..addOption('scope', help: 'Feature or scope name.'),
      );
  }

  Future<int> run(List<String> arguments, {String? projectRoot}) async {
    final parser = buildParser();
    try {
      final results = parser.parse(arguments);

      if (results.flag('help')) {
        _printUsage(parser);
        return 0;
      }
      if (results.flag('version')) {
        _logger.info('flutter_ai_context version: $cliVersion');
        return 0;
      }

      if (results.flag('verbose')) {
        _logger.level = LogLevel.verbose;
      } else if (results.flag('quiet')) {
        _logger.level = LogLevel.quiet;
      }

      final root = projectRoot ?? Directory.current.path;
      final command = results.command;

      if (command == null) {
        _logger.error('No command specified.');
        _printUsage(parser);
        return 64;
      }

      switch (command.name) {
        case 'init':
          return await InitCommand(logger: _logger).run(root);
        case 'scan':
          return await ScanCommand(logger: _logger).run(root);
        case 'sync':
          return await SyncCommand(logger: _logger).run(root);
        case 'status':
          return StatusCommand(logger: _logger).run(root);
        case 'doctor':
          return await DoctorCommand(logger: _logger).run(root);
        case 'context':
          if (command.flag('list')) {
            return ContextCommand(logger: _logger).listScopes(root);
          }
          final scope = command['scope'] as String? ??
              (command.rest.isNotEmpty ? command.rest.first : null);
          if (scope == null) {
            _logger.error(
              'Scope required. Usage: flutter_ai_context context <scope> '
              '(or --list)',
            );
            return 64;
          }
          return ContextCommand(logger: _logger).run(root, scope);
        default:
          _logger.error('Unknown command: ${command.name}');
          return 64;
      }
    } on FormatException catch (e) {
      _logger.error(e.message);
      _printUsage(parser);
      return 64;
    } catch (e) {
      _logger.error('$e');
      return 1;
    }
  }

  void _printUsage(ArgParser parser) {
    _logger.info(
        'Flutter AI Context — Give AI a real understanding of your Flutter project.');
    _logger.blank();
    _logger.info('Usage: flutter_ai_context <command> [options]');
    _logger.blank();
    _logger.info('Commands:');
    _logger.info('  init      Initialize AI context for this project');
    _logger.info('  scan      Full project analysis');
    _logger.info('  sync      Incremental update');
    _logger.info('  status    Check context freshness');
    _logger.info('  doctor    Architecture consistency check');
    _logger.info('  context   Generate focused context pack (--list)');
    _logger.blank();
    _logger.info('Global options:');
    _logger.info(parser.usage);
  }
}
