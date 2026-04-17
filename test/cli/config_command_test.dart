import 'dart:io';

import 'package:flutter_skill_gen/src/cli/cli_runner.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigCommand', () {
    test('command is registered', () {
      final runner = CliRunner();
      expect(runner.commands.keys, contains('config'));
    });

    test('has --set-key option', () {
      final runner = CliRunner();
      final cmd = runner.commands['config']!;
      expect(cmd.argParser.options.containsKey('set-key'), isTrue);
    });

    test('has --set-model option', () {
      final runner = CliRunner();
      final cmd = runner.commands['config']!;
      expect(cmd.argParser.options.containsKey('set-model'), isTrue);
    });

    test('has --remove-key flag', () {
      final runner = CliRunner();
      final cmd = runner.commands['config']!;
      expect(cmd.argParser.options.containsKey('remove-key'), isTrue);
    });

    test('has --add-target option', () {
      final runner = CliRunner();
      final cmd = runner.commands['config']!;
      expect(cmd.argParser.options.containsKey('add-target'), isTrue);
    });

    test('has --remove-target option', () {
      final runner = CliRunner();
      final cmd = runner.commands['config']!;
      expect(cmd.argParser.options.containsKey('remove-target'), isTrue);
    });

    test('has --init-skillrc flag', () {
      final runner = CliRunner();
      final cmd = runner.commands['config']!;
      expect(cmd.argParser.options.containsKey('init-skillrc'), isTrue);
    });

    test('--init-skillrc creates .skillrc.yaml', () {
      final tempDir = Directory.systemTemp.createTempSync(
        'flutter_skill_gen_config_cmd_test_',
      );

      try {
        final runner = CliRunner();
        final code = runner.run([
          'config',
          '--init-skillrc',
          '--path',
          tempDir.path,
        ]);

        expect(code, completes);

        final skillrc = File('${tempDir.path}/.skillrc.yaml');
        expect(skillrc.existsSync(), isTrue);
        expect(skillrc.readAsStringSync(), contains('output_targets'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
