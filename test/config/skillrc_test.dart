import 'dart:io';

import 'package:flutter_skill_gen/src/config/skillrc.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late Skillrc skillrc;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'flutter_skill_gen_skillrc_test_',
    );
    skillrc = Skillrc(projectPath: tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Skillrc', () {
    test('exists is false when no file present', () {
      expect(skillrc.exists, isFalse);
    });

    test('filePath points to .skillrc.yaml in project', () {
      expect(skillrc.filePath, endsWith('.skillrc.yaml'));
      expect(skillrc.filePath, contains(tempDir.path));
    });

    group('read', () {
      test('returns defaults when no file exists', () {
        final config = skillrc.read();
        expect(config.outputTargets, hasLength(1));
        expect(config.outputTargets.first.format, OutputFormat.generic);
        expect(config.watch.enabled, isTrue);
        expect(config.watch.debounceMs, 500);
      });

      test('parses output_targets from YAML', () {
        File(skillrc.filePath).writeAsStringSync('''
output_targets:
  - format: claude_code
  - format: cursor
  - format: generic

watch:
  enabled: true
  debounce_ms: 500
''');

        final config = skillrc.read();
        expect(config.outputTargets, hasLength(3));
        expect(config.outputTargets[0].format, OutputFormat.claudeCode);
        expect(config.outputTargets[1].format, OutputFormat.cursor);
        expect(config.outputTargets[2].format, OutputFormat.generic);
      });

      test('parses watch config', () {
        File(skillrc.filePath).writeAsStringSync('''
output_targets:
  - format: generic

watch:
  enabled: false
  debounce_ms: 1000
''');

        final config = skillrc.read();
        expect(config.watch.enabled, isFalse);
        expect(config.watch.debounceMs, 1000);
      });

      test('handles missing watch section', () {
        File(skillrc.filePath).writeAsStringSync('''
output_targets:
  - format: generic
''');

        final config = skillrc.read();
        expect(config.watch.enabled, isTrue);
        expect(config.watch.debounceMs, 500);
      });

      test('handles corrupt YAML gracefully', () {
        File(skillrc.filePath).writeAsStringSync('output_targets: [unclosed');

        final config = skillrc.read();
        // Falls back to defaults.
        expect(config.outputTargets, hasLength(1));
      });

      test('defaults output_targets when list is empty', () {
        File(skillrc.filePath).writeAsStringSync('''
output_targets: []
''');

        final config = skillrc.read();
        expect(config.outputTargets, hasLength(1));
        expect(config.outputTargets.first.format, OutputFormat.generic);
      });
    });

    group('write', () {
      test('creates .skillrc.yaml', () {
        skillrc.write(const SkillrcConfig());
        expect(skillrc.exists, isTrue);
      });

      test('written file is readable', () {
        const config = SkillrcConfig(
          outputTargets: [
            OutputTarget(format: OutputFormat.claudeCode),
            OutputTarget(format: OutputFormat.cursor),
          ],
          watch: WatchConfig(enabled: false, debounceMs: 250),
        );

        skillrc.write(config);
        final readBack = skillrc.read();

        expect(readBack.outputTargets, hasLength(2));
        expect(readBack.outputTargets[0].format, OutputFormat.claudeCode);
        expect(readBack.outputTargets[1].format, OutputFormat.cursor);
        expect(readBack.watch.enabled, isFalse);
        expect(readBack.watch.debounceMs, 250);
      });

      test('written file contains comments', () {
        skillrc.write(const SkillrcConfig());
        final content = File(skillrc.filePath).readAsStringSync();
        expect(content, contains('# flutter_skill_gen project configuration'));
      });
    });

    group('createDefault', () {
      test('creates file with default config', () {
        skillrc.createDefault();
        expect(skillrc.exists, isTrue);

        final config = skillrc.read();
        expect(config.outputTargets, hasLength(1));
        expect(config.outputTargets.first.format, OutputFormat.generic);
        expect(config.watch.enabled, isTrue);
        expect(config.watch.debounceMs, 500);
      });
    });
  });

  group('OutputFormat', () {
    test('contains all expected formats', () {
      expect(OutputFormat.all, contains('claude_code'));
      expect(OutputFormat.all, contains('cursor'));
      expect(OutputFormat.all, contains('copilot'));
      expect(OutputFormat.all, contains('windsurf'));
      expect(OutputFormat.all, contains('antigravity'));
      expect(OutputFormat.all, contains('antigravity_rules'));
      expect(OutputFormat.all, contains('agents_md'));
      expect(OutputFormat.all, contains('generic'));
    });

    test('has 8 formats', () {
      expect(OutputFormat.all, hasLength(8));
    });
  });
}
