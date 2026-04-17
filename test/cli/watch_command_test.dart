import 'dart:io';

import 'package:flutter_skill_gen/src/cli/cli_runner.dart';
import 'package:test/test.dart';

void main() {
  group('WatchCommand', () {
    test('command is registered', () {
      final runner = CliRunner();
      expect(runner.commands.keys, contains('watch'));
    });

    test('has --path option', () {
      final runner = CliRunner();
      final cmd = runner.commands['watch']!;
      expect(cmd.argParser.options.containsKey('path'), isTrue);
    });

    test('has --debounce option', () {
      final runner = CliRunner();
      final cmd = runner.commands['watch']!;
      expect(cmd.argParser.options.containsKey('debounce'), isTrue);
    });

    test('has --verbose flag', () {
      final runner = CliRunner();
      final cmd = runner.commands['watch']!;
      expect(cmd.argParser.options.containsKey('verbose'), isTrue);
    });

    test('fails when no lib/ directory exists', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'flutter_skill_gen_watch_test_',
      );

      try {
        final runner = CliRunner();
        final code = await runner.run(['watch', '--path', tempDir.path]);

        expect(code, 64);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
