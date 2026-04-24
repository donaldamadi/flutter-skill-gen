import 'package:flutter_skill_gen/src/scanner/project_scanner.dart';
import 'package:flutter_skill_gen/src/utils/logger.dart';
import 'package:test/test.dart';

/// Regression tests against the three 0.3.1 fixes surfaced by the
/// `tng_laws_ai_mobile` audit against 0.3.0:
///
/// 1. `_recommendSkillFiles` silently capped the feature list at 5
///    via `.take(5)`, dropping profile / onboarding / shared /
///    navigation from the manifest and split plan.
/// 2. `PubspecAnalyzer.analyzeDependencies` threw away every dev
///    dependency that wasn't a codegen or testing helper, so
///    flutter_lints / flutter_launcher_icons / flutter_native_splash
///    never appeared in `.skill_facts.json`.
/// 3. `_analyzeTests` reported `hasWidgetTests=true` for the stock
///    `flutter create` counter-increment stub, inflating the test
///    signal in freshly scaffolded projects.
void main() {
  group('Audit 0.3.1 fixes', () {
    late ProjectScanner scanner;

    setUp(() {
      scanner = ProjectScanner(
        projectPath: 'test/fixtures/sample_many_features_project',
        logger: const Logger(),
      );
    });

    test('every detected feature survives into recommendedSkillFiles', () {
      final facts = scanner.scan()!;
      expect(
        facts.structure.featureDirs.length,
        greaterThan(5),
        reason: 'Fixture must have more than 5 features to exercise the cap.',
      );

      final recommended = facts.complexity!.recommendedSkillFiles;
      for (final feature in facts.structure.featureDirs) {
        expect(
          recommended,
          contains(feature),
          reason:
              '$feature was dropped. The .take(5) cap in '
              '_recommendSkillFiles must be removed.',
        );
      }
    });

    test('dev-only dependencies are preserved in DependencyInfo', () {
      final facts = scanner.scan()!;
      final devDeps = facts.dependencies.devDependencies;
      expect(
        devDeps,
        containsAll([
          'flutter_lints',
          'flutter_launcher_icons',
          'flutter_native_splash',
        ]),
        reason:
            'Dev-only packages must be captured so skill generation '
            'can reflect them (they were silently dropped in 0.3.0).',
      );
      // `flutter` itself is excluded — it is the SDK, not a package.
      expect(devDeps, isNot(contains('flutter')));
      // Testing helpers still flow into the `testing` bucket as before.
      expect(facts.dependencies.testing, isNot(contains('flutter_lints')));
    });

    test(
      'stock flutter create widget_test.dart does not count as widget tests',
      () {
        final facts = scanner.scan()!;
        expect(
          facts.testing?.hasWidgetTests,
          isFalse,
          reason:
              'The stock counter-increment stub must be excluded. '
              'Otherwise every freshly scaffolded project looks like '
              'it has widget tests.',
        );
      },
    );
  });
}
