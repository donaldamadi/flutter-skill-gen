import 'package:flutter_skill_gen/src/analyzers/domain_analyzer.dart';
import 'package:flutter_skill_gen/src/analyzers/structure_analyzer.dart';
import 'package:flutter_skill_gen/src/generators/split_planner.dart';
import 'package:flutter_skill_gen/src/scanner/project_scanner.dart';
import 'package:test/test.dart';

/// A real-world layout that put features at `lib/ui/modules/<name>`.
///
/// `modules` was recognised as a feature container at the top level but
/// not when nested inside a layer, so a 655-file app reported zero
/// features and collapsed to a single SKILL.md.
const _fixture = 'test/fixtures/sample_ui_modules_project';

void main() {
  group('features nested in a layer container', () {
    test('detects features at lib/ui/modules', () {
      final info = StructureAnalyzer(_fixture).analyze();

      expect(info.featureDirs, containsAll(['auth', 'payments']));
    });

    test('does not mistake sibling support folders for features', () {
      final info = StructureAnalyzer(_fixture).analyze();

      expect(info.featureDirs, isNot(contains('widgets')));
      expect(info.featureDirs, isNot(contains('theme')));
    });

    test('reports feature-first rather than flat', () {
      // "flat" is what a project reports when nothing was found; it is
      // the symptom users see before the split silently disappears.
      expect(
        StructureAnalyzer(_fixture).analyze().organization,
        'feature-first',
      );
    });

    test('resolves each feature directory for per-feature analysis', () {
      // Detection and resolution have to agree: a feature the structure
      // analyzer finds but the domain analyzer cannot open is dropped
      // from the plan, which is how the split vanished.
      final structure = StructureAnalyzer(_fixture).analyze();
      final analyzer = DomainAnalyzer(_fixture);

      for (final feature in structure.featureDirs) {
        final facts = analyzer.analyze(feature, structure);
        expect(
          facts.files,
          isNotEmpty,
          reason: 'no files resolved for feature "$feature"',
        );
      }
    });

    test('plans one skill file per feature plus core', () {
      final facts = ProjectScanner(projectPath: _fixture).scan();
      expect(facts, isNotNull);

      final plan = const SplitPlanner().plan(
        facts!,
        projectPath: _fixture,
        forceSplit: true,
      );

      expect(plan.isSplit, isTrue);
      expect(
        plan.specs.map((s) => s.skillName),
        containsAll(['core', 'auth', 'payments']),
      );
    });
  });

  group('container lists stay in lockstep', () {
    test('every top-level container is also recognised when nested', () {
      // The bug was a nested list that had drifted from the top-level
      // one. Deriving it is the fix; this is the guard.
      for (final container in StructureAnalyzer.featureContainerNames) {
        for (final layer in StructureAnalyzer.layerContainerNames) {
          expect(
            StructureAnalyzer.nestedFeatureContainers,
            contains('$layer/$container'),
          );
        }
      }
    });
  });
}
