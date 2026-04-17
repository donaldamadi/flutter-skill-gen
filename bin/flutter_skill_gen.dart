import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_skill_gen/src/cli/cli_runner.dart';

Future<void> main(List<String> arguments) async {
  final runner = CliRunner();
  try {
    final exitCode = await runner.run(arguments) ?? 0;
    exit(exitCode);
  } on UsageException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln(e.usage);
    exit(64);
  }
}
