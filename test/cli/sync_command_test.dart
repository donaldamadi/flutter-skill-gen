import 'dart:io';

import 'package:flutter_skill_gen/src/cli/cli_runner.dart';
import 'package:test/test.dart';

void main() {
  group('SyncCommand', () {
    test('fails for nonexistent project path', () async {
      final runner = CliRunner();
      final code = await runner.run([
        'sync',
        '--path',
        '/nonexistent/flutter/project',
      ]);

      expect(code, 64);
    });

    test('fails for path without pubspec.yaml', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'flutter_skill_gen_sync_test_',
      );

      try {
        final runner = CliRunner();
        final code = await runner.run(['sync', '--path', tempDir.path]);

        expect(code, 64);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('returns exit code 1 in CI mode on failure', () async {
      final runner = CliRunner();
      final code = await runner.run([
        'sync',
        '--path',
        '/nonexistent/flutter/project',
        '--ci',
      ]);

      expect(code, 1);
    });

    test('succeeds on a valid project (uses bloc fixture)', () async {
      final runner = CliRunner();
      final code = await runner.run([
        'sync',
        '--path',
        'test/fixtures/sample_bloc_project',
      ]);

      expect(code, 0);

      // Verify generated files.
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
    });
  });
}
