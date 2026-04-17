import 'package:flutter_skill_gen/src/cli/cli_runner.dart';
import 'package:test/test.dart';

void main() {
  group('HooksCommand', () {
    late CliRunner runner;

    setUp(() {
      runner = CliRunner();
    });

    test('hooks command is registered', () {
      final names = runner.commands.keys;
      expect(names, contains('hooks'));
    });

    test('hooks command has correct description', () {
      final cmd = runner.commands['hooks']!;
      expect(cmd.description, contains('git hooks'));
      expect(cmd.description, contains('CI'));
    });

    test('hooks command has --install flag', () {
      final cmd = runner.commands['hooks']!;
      expect(cmd.argParser.options.containsKey('install'), isTrue);
    });

    test('hooks command has --remove flag', () {
      final cmd = runner.commands['hooks']!;
      expect(cmd.argParser.options.containsKey('remove'), isTrue);
    });

    test('hooks command has --github-action flag', () {
      final cmd = runner.commands['hooks']!;
      expect(cmd.argParser.options.containsKey('github-action'), isTrue);
    });

    test('hooks command has --status flag', () {
      final cmd = runner.commands['hooks']!;
      expect(cmd.argParser.options.containsKey('status'), isTrue);
    });

    test('hooks command has --dart-only flag', () {
      final cmd = runner.commands['hooks']!;
      expect(cmd.argParser.options.containsKey('dart-only'), isTrue);
    });
  });

  group('CliRunner with hooks', () {
    test('registers 7 commands (6 + help)', () {
      final runner = CliRunner();
      // analyze, config, hooks, init, sync, watch + auto help
      expect(runner.commands.keys, hasLength(7));
    });
  });
}
