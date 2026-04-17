import 'dart:io';

import 'package:flutter_skill_gen/src/cli/cli_runner.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'flutter_skill_gen_init_cmd_test_',
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('InitCommand', () {
    test('fails when no --arch or --from-repo given', () async {
      final runner = CliRunner();
      final code = await runner.run([
        'init',
        '--output',
        '${tempDir.path}/test_app',
      ]);

      expect(code, 64);
    });

    test('fails when both --arch and --from-repo given', () async {
      final runner = CliRunner();
      final code = await runner.run([
        'init',
        '--arch',
        'clean_bloc',
        '--from-repo',
        'https://github.com/user/repo',
        '--output',
        '${tempDir.path}/test_app',
      ]);

      expect(code, 64);
    });

    test('fails for unknown template', () async {
      final runner = CliRunner();
      final code = await runner.run([
        'init',
        '--arch',
        'unknown_template',
        '--output',
        '${tempDir.path}/test_app',
      ]);

      expect(code, 64);
    });

    test(
      'scaffolds clean_bloc template successfully',
      () async {
        final outputPath = '${tempDir.path}/bloc_app';
        final runner = CliRunner();
        final code = await runner.run([
          'init',
          '--arch',
          'clean_bloc',
          '--name',
          'my_bloc_app',
          '--output',
          outputPath,
        ]);

        expect(code, 0);
        expect(File('$outputPath/pubspec.yaml').existsSync(), isTrue);
        expect(File('$outputPath/SKILL.md').existsSync(), isTrue);
        expect(File('$outputPath/.skill_facts.json').existsSync(), isTrue);
        expect(File('$outputPath/.skill_manifest.yaml').existsSync(), isTrue);
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    test(
      'scaffolds clean_riverpod template successfully',
      () async {
        final outputPath = '${tempDir.path}/riverpod_app';
        final runner = CliRunner();
        final code = await runner.run([
          'init',
          '--arch',
          'clean_riverpod',
          '--name',
          'my_riverpod_app',
          '--output',
          outputPath,
        ]);

        expect(code, 0);
        expect(File('$outputPath/pubspec.yaml').existsSync(), isTrue);
        final content = File('$outputPath/pubspec.yaml').readAsStringSync();
        expect(content, contains('name: my_riverpod_app'));
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    test(
      'generated SKILL.md contains project name',
      () async {
        final outputPath = '${tempDir.path}/bloc_app';
        final runner = CliRunner();
        await runner.run([
          'init',
          '--arch',
          'clean_bloc',
          '--name',
          'bloc_app',
          '--output',
          outputPath,
        ]);

        final skillContent = File('$outputPath/SKILL.md').readAsStringSync();
        expect(skillContent, contains('bloc_app'));
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );
  });
}
