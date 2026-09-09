import 'dart:io';

import 'package:flutter_ai_context/src/cli/runner.dart';

Future<void> main(List<String> arguments) async {
  final exitCode = await CliRunner().run(arguments);
  exit(exitCode);
}
