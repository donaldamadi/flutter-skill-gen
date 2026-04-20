import 'dart:io';

import 'package:flutter_skill_gen/src/generators/skill_generator.dart';
import 'package:flutter_skill_gen/src/models/convention_info.dart';
import 'package:flutter_skill_gen/src/models/dependency_info.dart';
import 'package:flutter_skill_gen/src/models/pattern_info.dart';
import 'package:flutter_skill_gen/src/models/project_facts.dart';
import 'package:flutter_skill_gen/src/models/structure_info.dart';
import 'package:test/test.dart';

ProjectFacts _buildFacts({
  String projectName = 'test_app',
  PatternInfo patterns = const PatternInfo(),
}) {
  return ProjectFacts(
    projectName: projectName,
    dependencies: const DependencyInfo(),
    structure: const StructureInfo(organization: 'feature-first'),
    patterns: patterns,
    conventions: const ConventionInfo(),
    generatedAt: '2026-04-16T12:00:00Z',
    toolVersion: '0.1.0',
  );
}

void main() {
  group('SkillGenerator', () {
    group('hasAi', () {
      test('returns false when apiKey is null', () {
        final gen = SkillGenerator();
        expect(gen.hasAi, isFalse);
      });

      test('returns false when apiKey is empty', () {
        final gen = SkillGenerator(apiKey: '');
        expect(gen.hasAi, isFalse);
      });

      test('returns true when apiKey is provided', () {
        final gen = SkillGenerator(apiKey: 'sk-ant-test-key');
        expect(gen.hasAi, isTrue);
      });
    });

    group('generate (template fallback)', () {
      test('uses template generator when no API key', () async {
        final gen = SkillGenerator();
        final md = await gen.generate(_buildFacts());

        // Template generator starts with H1 project name.
        expect(md, contains('# test_app'));
        expect(md, contains('## Architecture'));
      });

      test('template output includes patterns when present', () async {
        final gen = SkillGenerator();
        final md = await gen.generate(
          _buildFacts(
            patterns: const PatternInfo(
              architecture: 'clean_architecture',
              stateManagement: 'bloc',
            ),
          ),
        );

        expect(md, contains('**Clean Architecture**'));
        expect(md, contains('## State Management'));
      });
    });

    group('generateAndWrite', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync(
          'flutter_skill_gen_skillgen_test_',
        );
      });

      tearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('writes SKILL.md to output directory', () async {
        final gen = SkillGenerator();
        final path = await gen.generateAndWrite(
          _buildFacts(),
          outputDir: tempDir.path,
        );

        expect(path, endsWith('SKILL.md'));
        expect(File(path).existsSync(), isTrue);
      });

      test('file content matches generate output', () async {
        final facts = _buildFacts();
        final gen = SkillGenerator();

        final path = await gen.generateAndWrite(facts, outputDir: tempDir.path);

        final written = File(path).readAsStringSync();
        final expected = await gen.generate(facts);
        expect(written, expected);
      });

      test('creates parent directories if needed', () async {
        final gen = SkillGenerator();
        final nestedDir = '${tempDir.path}/nested/deep';
        final path = await gen.generateAndWrite(
          _buildFacts(),
          outputDir: nestedDir,
        );

        expect(File(path).existsSync(), isTrue);
      });
    });

    group('model default', () {
      test('defaults to claude-sonnet-4-6', () {
        final gen = SkillGenerator();
        expect(gen.model, 'claude-sonnet-4-6');
      });

      test('accepts custom model', () {
        final gen = SkillGenerator(apiKey: 'sk-test', model: 'claude-opus-4-7');
        expect(gen.model, 'claude-opus-4-7');
      });
    });
  });
}
