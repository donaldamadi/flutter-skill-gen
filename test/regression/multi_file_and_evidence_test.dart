import 'dart:io';

import 'package:flutter_skill_gen/src/config/skillrc.dart';
import 'package:flutter_skill_gen/src/generators/manifest_generator.dart';
import 'package:flutter_skill_gen/src/generators/skill_generator.dart';
import 'package:flutter_skill_gen/src/generators/split_planner.dart';
import 'package:flutter_skill_gen/src/output/target_writer.dart';
import 'package:flutter_skill_gen/src/scanner/project_scanner.dart';
import 'package:flutter_skill_gen/src/utils/logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Regression tests against the two bugs surfaced by the moneypal
/// audit:
///
/// 1. `feature_evidence[].file_count: 0` — per-feature evidence was
///    empty because `DomainAnalyzer` couldn't locate features in
///    layer-first projects where each feature sits directly under
///    `lib/ui/<feature>` (no intermediate `pages/`, `features/`, or
///    `screens/` container).
/// 2. `.skill_manifest.yaml` promised `SKILL_<feature>.md` files
///    that never landed on disk — the default `generic` and
///    `claude_code` writers concatenated split-mode output into a
///    single file instead of writing siblings.
void main() {
  group('Bug A2: per-feature evidence population', () {
    group('feature-first fixture (sample_bloc_project)', () {
      // Only `auth` has dart files in this fixture; `home` and `cart`
      // are intentional stubs that exercise the empty-feature edge
      // case.
      test('auth feature reports fileCount matching its dart files', () {
        final scanner = ProjectScanner(
          projectPath: 'test/fixtures/sample_bloc_project',
          logger: const Logger(),
        );
        final facts = scanner.scan()!;
        final auth = facts.evidence!.features.firstWhere(
          (f) => f.name == 'auth',
        );

        expect(
          auth.fileCount,
          greaterThanOrEqualTo(3),
          reason:
              'DomainAnalyzer must populate fileCount for '
              'feature-first projects.',
        );
        expect(auth.path, 'lib/features/auth');
      });
    });

    group('layer-first fixture (sample_layer_first_project)', () {
      test(
        'features under lib/ui/<name> are populated with their dart files',
        () {
          final scanner = ProjectScanner(
            projectPath: 'test/fixtures/sample_layer_first_project',
            logger: const Logger(),
          );
          final facts = scanner.scan()!;
          final evidence = facts.evidence!;

          expect(
            evidence.features.map((f) => f.name),
            containsAll(['auth', 'profile']),
          );

          final auth = evidence.features.firstWhere((f) => f.name == 'auth');
          expect(auth.path, 'lib/ui/auth');
          expect(
            auth.fileCount,
            greaterThan(0),
            reason:
                'Layer-first bug: DomainAnalyzer must resolve '
                'lib/ui/auth even when no features/pages/screens '
                'container is present.',
          );

          final profile = evidence.features.firstWhere(
            (f) => f.name == 'profile',
          );
          expect(profile.path, 'lib/ui/profile');
          expect(profile.fileCount, greaterThan(0));
        },
      );
    });
  });

  group('Bug A1: multi-file output lands on disk', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'flutter_skill_gen_multifile_test_',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('forced split produces sibling SKILL_<feature>.md files, '
        'not a single concatenated SKILL.md', () async {
      final scanner = ProjectScanner(
        projectPath: 'test/fixtures/sample_bloc_project',
        logger: const Logger(),
      );
      final facts = scanner.scan()!;

      const planner = SplitPlanner();
      final plan = planner.plan(
        facts,
        projectPath: 'test/fixtures/sample_bloc_project',
        forceSplit: true,
      );
      expect(plan.isSplit, isTrue);
      expect(plan.specs.map((s) => s.skillName), containsAll(['core', 'auth']));

      final skillGen = SkillGenerator(logger: const Logger());
      final skills = await skillGen.generateAll(plan, facts);

      // Keys in the skills map must be the unprefixed scope names
      // so multi-file writers produce clean `SKILL_<name>.md`
      // filenames.
      expect(skills.keys, contains('core'));
      expect(skills.keys, contains('auth'));

      // Default `generic` target.
      const config = SkillrcConfig(
        outputTargets: [OutputTarget(format: OutputFormat.generic)],
      );
      TargetWriter(
        logger: const Logger(),
      ).writeMultiSkill(skills, projectPath: tempDir.path, config: config);

      final coreFile = File(p.join(tempDir.path, 'SKILL.md'));
      expect(
        coreFile.existsSync(),
        isTrue,
        reason: 'Core SKILL.md must be written to project root.',
      );

      for (final scope
          in plan.specs
              .where((s) => s.skillName != 'core')
              .map((s) => s.skillName)) {
        final featureFile = File(p.join(tempDir.path, 'SKILL_$scope.md'));
        expect(
          featureFile.existsSync(),
          isTrue,
          reason:
              'SKILL_$scope.md missing. The generic writer must '
              'produce sibling files in split mode.',
        );
        expect(
          featureFile.readAsStringSync(),
          contains('---'),
          reason: 'SKILL_$scope.md must start with YAML frontmatter.',
        );
      }
    });

    test('claude_code target writes CLAUDE.md + CLAUDE_<feature>.md', () async {
      final scanner = ProjectScanner(
        projectPath: 'test/fixtures/sample_bloc_project',
        logger: const Logger(),
      );
      final facts = scanner.scan()!;

      const planner = SplitPlanner();
      final plan = planner.plan(
        facts,
        projectPath: 'test/fixtures/sample_bloc_project',
        forceSplit: true,
      );
      final skillGen = SkillGenerator(logger: const Logger());
      final skills = await skillGen.generateAll(plan, facts);

      const config = SkillrcConfig(
        outputTargets: [OutputTarget(format: OutputFormat.claudeCode)],
      );
      TargetWriter(
        logger: const Logger(),
      ).writeMultiSkill(skills, projectPath: tempDir.path, config: config);

      expect(File(p.join(tempDir.path, 'CLAUDE.md')).existsSync(), isTrue);
      expect(File(p.join(tempDir.path, 'CLAUDE_auth.md')).existsSync(), isTrue);
    });

    test(
      'manifest references only skills that will actually be written',
      () async {
        final scanner = ProjectScanner(
          projectPath: 'test/fixtures/sample_bloc_project',
          logger: const Logger(),
        );
        final facts = scanner.scan()!;

        const planner = SplitPlanner();
        final plan = planner.plan(
          facts,
          projectPath: 'test/fixtures/sample_bloc_project',
          forceSplit: true,
        );
        final skillGen = SkillGenerator(logger: const Logger());
        final skills = await skillGen.generateAll(plan, facts);

        const config = SkillrcConfig(
          outputTargets: [OutputTarget(format: OutputFormat.generic)],
        );
        TargetWriter(
          logger: const Logger(),
        ).writeMultiSkill(skills, projectPath: tempDir.path, config: config);

        ManifestGenerator.write(facts, outputDir: tempDir.path, plan: plan);

        final manifestContent = File(
          p.join(tempDir.path, '.skill_manifest.yaml'),
        ).readAsStringSync();

        // Every SKILL_<x>.md referenced in the manifest must exist.
        final referencePattern = RegExp(r'file:\s*SKILL_([a-zA-Z0-9_-]+)\.md');
        for (final match in referencePattern.allMatches(manifestContent)) {
          final scope = match.group(1)!;
          final file = File(p.join(tempDir.path, 'SKILL_$scope.md'));
          expect(
            file.existsSync(),
            isTrue,
            reason:
                'Manifest references SKILL_$scope.md but the file '
                'was never written. This is the moneypal '
                'phantom-manifest bug.',
          );
        }
      },
    );
  });
}
