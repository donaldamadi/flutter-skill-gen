import 'dart:io';

import 'package:flutter_skill_gen/src/cli/cli_runner.dart';
import 'package:test/test.dart';

void main() {
  group('AnalyzeCommand', () {
    test('command is registered', () {
      final runner = CliRunner();
      expect(runner.commands.keys, contains('analyze'));
    });

    test('has --path option', () {
      final runner = CliRunner();
      final cmd = runner.commands['analyze']!;
      expect(cmd.argParser.options.containsKey('path'), isTrue);
    });

    test('has --output option', () {
      final runner = CliRunner();
      final cmd = runner.commands['analyze']!;
      expect(cmd.argParser.options.containsKey('output'), isTrue);
    });

    test('has --facts-only flag', () {
      final runner = CliRunner();
      final cmd = runner.commands['analyze']!;
      expect(cmd.argParser.options.containsKey('facts-only'), isTrue);
    });

    test('has --verbose flag', () {
      final runner = CliRunner();
      final cmd = runner.commands['analyze']!;
      expect(cmd.argParser.options.containsKey('verbose'), isTrue);
    });

    test('fails for nonexistent path', () async {
      final runner = CliRunner();
      final code = await runner.run([
        'analyze',
        '--path',
        '/nonexistent/flutter/project',
      ]);

      expect(code, 64);
    });

    test('fails for path without pubspec.yaml', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'flutter_skill_gen_analyze_test_',
      );

      try {
        final runner = CliRunner();
        final code = await runner.run(['analyze', '--path', tempDir.path]);

        expect(code, 64);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'succeeds on valid project (bloc fixture)',
      () async {
        final runner = CliRunner();
        final code = await runner.run([
          'analyze',
          '--path',
          'test/fixtures/sample_bloc_project',
        ]);

        expect(code, 0);

        // Verify generated artifacts.
        expect(
          File(
            'test/fixtures/sample_bloc_project/'
            '.skill_facts.json',
          ).existsSync(),
          isTrue,
        );
        expect(
          File('test/fixtures/sample_bloc_project/SKILL.md').existsSync(),
          isTrue,
        );
        expect(
          File(
            'test/fixtures/sample_bloc_project/'
            '.skill_manifest.yaml',
          ).existsSync(),
          isTrue,
        );
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    test('--facts-only skips SKILL.md generation', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'flutter_skill_gen_analyze_factsonly_',
      );

      try {
        final runner = CliRunner();
        final code = await runner.run([
          'analyze',
          '--path',
          'test/fixtures/sample_riverpod_project',
          '--output',
          tempDir.path,
          '--facts-only',
        ]);

        expect(code, 0);
        expect(File('${tempDir.path}/.skill_facts.json').existsSync(), isTrue);
        // SKILL.md and manifest should NOT be generated.
        expect(File('${tempDir.path}/SKILL.md').existsSync(), isFalse);
        expect(
          File('${tempDir.path}/.skill_manifest.yaml').existsSync(),
          isFalse,
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
