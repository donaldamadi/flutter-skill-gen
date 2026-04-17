import 'dart:io';

import 'package:flutter_skill_gen/src/config/skillrc.dart';
import 'package:flutter_skill_gen/src/output/target_writer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('TargetWriter', () {
    late Directory tempDir;
    late TargetWriter writer;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'flutter_skill_gen_target_writer_test_',
      );
      writer = TargetWriter();
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('registeredFormats', () {
      test('includes all 8 known formats', () {
        final formats = TargetWriter.registeredFormats;
        expect(formats, hasLength(8));
        expect(
          formats,
          containsAll([
            OutputFormat.claudeCode,
            OutputFormat.cursor,
            OutputFormat.copilot,
            OutputFormat.windsurf,
            OutputFormat.antigravity,
            OutputFormat.antigravityRules,
            OutputFormat.agentsMd,
            OutputFormat.generic,
          ]),
        );
      });
    });

    group('writerFor', () {
      test('returns writer for known format', () {
        final w = TargetWriter.writerFor(OutputFormat.claudeCode);
        expect(w, isNotNull);
        expect(w!.format, OutputFormat.claudeCode);
      });

      test('returns null for unknown format', () {
        expect(TargetWriter.writerFor('unknown'), isNull);
      });
    });

    group('format output paths', () {
      test('claude_code writes CLAUDE.md', () {
        final w = TargetWriter.writerFor(OutputFormat.claudeCode)!;
        expect(w.outputPath(tempDir.path), endsWith('CLAUDE.md'));
      });

      test('cursor writes .cursorrules', () {
        final w = TargetWriter.writerFor(OutputFormat.cursor)!;
        expect(w.outputPath(tempDir.path), endsWith('.cursorrules'));
      });

      test('copilot writes .github/copilot-instructions.md', () {
        final w = TargetWriter.writerFor(OutputFormat.copilot)!;
        final path = w.outputPath(tempDir.path);
        expect(path, contains('.github'));
        expect(path, endsWith('copilot-instructions.md'));
      });

      test('windsurf writes .windsurfrules', () {
        final w = TargetWriter.writerFor(OutputFormat.windsurf)!;
        expect(w.outputPath(tempDir.path), endsWith('.windsurfrules'));
      });

      test('antigravity writes .agents/skills/<name>/SKILL.md', () {
        final w = TargetWriter.writerFor(OutputFormat.antigravity)!;
        final path = w.outputPath(tempDir.path, skillName: 'auth');
        expect(path, contains('.agents'));
        expect(path, contains('skills'));
        expect(path, contains('auth'));
        expect(path, endsWith('SKILL.md'));
      });

      test('antigravity defaults skill name to core', () {
        final w = TargetWriter.writerFor(OutputFormat.antigravity)!;
        final path = w.outputPath(tempDir.path);
        expect(path, contains('core'));
      });

      test('antigravity_rules writes .gemini/GEMINI.md', () {
        final w = TargetWriter.writerFor(OutputFormat.antigravityRules)!;
        final path = w.outputPath(tempDir.path);
        expect(path, contains('.gemini'));
        expect(path, endsWith('GEMINI.md'));
      });

      test('agents_md writes AGENTS.md', () {
        final w = TargetWriter.writerFor(OutputFormat.agentsMd)!;
        expect(w.outputPath(tempDir.path), endsWith('AGENTS.md'));
      });

      test('generic writes SKILL.md', () {
        final w = TargetWriter.writerFor(OutputFormat.generic)!;
        expect(w.outputPath(tempDir.path), endsWith('SKILL.md'));
      });
    });

    group('FormatWriter.write', () {
      test('creates file with content', () {
        final w = TargetWriter.writerFor(OutputFormat.generic)!
          ..write('# Skill Content', projectPath: tempDir.path);

        final file = File(w.outputPath(tempDir.path));
        expect(file.existsSync(), isTrue);
        expect(file.readAsStringSync(), '# Skill Content');
      });

      test('creates parent directories', () {
        final w = TargetWriter.writerFor(OutputFormat.copilot)!
          ..write('# Copilot Skill', projectPath: tempDir.path);

        final file = File(w.outputPath(tempDir.path));
        expect(file.existsSync(), isTrue);
      });

      test('overwrites existing file', () {
        final w = TargetWriter.writerFor(OutputFormat.generic)!
          ..write('version 1', projectPath: tempDir.path)
          ..write('version 2', projectPath: tempDir.path);

        final file = File(w.outputPath(tempDir.path));
        expect(file.readAsStringSync(), 'version 2');
      });
    });

    group('writeToTargets', () {
      test('writes to single generic target', () {
        const config = SkillrcConfig(
          outputTargets: [OutputTarget(format: OutputFormat.generic)],
        );

        writer.writeToTargets(
          '# Test Content',
          projectPath: tempDir.path,
          config: config,
        );

        final file = File(p.join(tempDir.path, 'SKILL.md'));
        expect(file.existsSync(), isTrue);
        expect(file.readAsStringSync(), '# Test Content');
      });

      test('writes to multiple targets', () {
        const config = SkillrcConfig(
          outputTargets: [
            OutputTarget(format: OutputFormat.generic),
            OutputTarget(format: OutputFormat.claudeCode),
            OutputTarget(format: OutputFormat.cursor),
          ],
        );

        writer.writeToTargets(
          '# Multi Target',
          projectPath: tempDir.path,
          config: config,
        );

        expect(File(p.join(tempDir.path, 'SKILL.md')).existsSync(), isTrue);
        expect(File(p.join(tempDir.path, 'CLAUDE.md')).existsSync(), isTrue);
        expect(File(p.join(tempDir.path, '.cursorrules')).existsSync(), isTrue);
      });

      test('skips unknown formats without throwing', () {
        const config = SkillrcConfig(
          outputTargets: [
            OutputTarget(format: 'nonexistent'),
            OutputTarget(format: OutputFormat.generic),
          ],
        );

        // Should not throw.
        writer.writeToTargets(
          '# Content',
          projectPath: tempDir.path,
          config: config,
        );

        // Generic should still be written.
        expect(File(p.join(tempDir.path, 'SKILL.md')).existsSync(), isTrue);
      });

      test('all targets get identical content', () {
        const config = SkillrcConfig(
          outputTargets: [
            OutputTarget(format: OutputFormat.generic),
            OutputTarget(format: OutputFormat.claudeCode),
          ],
        );
        const content = '# Same Content Everywhere';

        writer.writeToTargets(
          content,
          projectPath: tempDir.path,
          config: config,
        );

        expect(
          File(p.join(tempDir.path, 'SKILL.md')).readAsStringSync(),
          content,
        );
        expect(
          File(p.join(tempDir.path, 'CLAUDE.md')).readAsStringSync(),
          content,
        );
      });
    });
  });
}
