import 'package:flutter_skill_gen/src/cli/cli_runner.dart';
import 'package:test/test.dart';

void main() {
  group('CliRunner', () {
    late CliRunner runner;

    setUp(() {
      runner = CliRunner();
    });

    test('has correct executable name', () {
      expect(runner.executableName, 'flutter_skill_gen');
    });

    test('has description', () {
      expect(runner.description, isNotEmpty);
    });

    test('registers analyze command', () {
      final commands = runner.commands;
      expect(commands, contains('analyze'));
    });

    test('registers config command', () {
      final commands = runner.commands;
      expect(commands, contains('config'));
    });

    test('registers init command', () {
      final commands = runner.commands;
      expect(commands, contains('init'));
    });

    test('registers sync command', () {
      final commands = runner.commands;
      expect(commands, contains('sync'));
    });

    test('registers hooks command', () {
      final commands = runner.commands;
      expect(commands, contains('hooks'));
    });

    test('registers watch command', () {
      final commands = runner.commands;
      expect(commands, contains('watch'));
    });

    test('has 10 registered commands (9 + help)', () {
      // analyze, assemble, config, hooks, init, install-skill,
      // prompt, sync, watch + auto-registered help
      expect(runner.commands, hasLength(10));
    });

    test('registers the keyless agent-driven commands', () {
      final commands = runner.commands.keys;
      expect(commands, contains('prompt'));
      expect(commands, contains('assemble'));
      expect(commands, contains('install-skill'));
    });
  });
}
