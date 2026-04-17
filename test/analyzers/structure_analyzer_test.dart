import 'package:flutter_skill_gen/src/analyzers/structure_analyzer.dart';
import 'package:test/test.dart';

void main() {
  group('StructureAnalyzer', () {
    group('sample_bloc_project (feature-first, clean arch)', () {
      late StructureAnalyzer analyzer;

      setUp(() {
        analyzer = StructureAnalyzer('test/fixtures/sample_bloc_project');
      });

      test('detects feature-first organization', () {
        final result = analyzer.analyze();
        expect(result.organization, 'feature-first');
      });

      test('finds top-level directories', () {
        final result = analyzer.analyze();
        expect(
          result.topLevelDirs,
          containsAll(['core', 'features', 'shared']),
        );
      });

      test('finds feature directories', () {
        final result = analyzer.analyze();
        expect(result.featureDirs, containsAll(['auth', 'home', 'cart']));
      });

      test('detects no separate packages', () {
        final result = analyzer.analyze();
        expect(result.hasSeparatePackages, isFalse);
      });

      test('detects clean architecture layers per-feature', () {
        final result = analyzer.analyze();
        expect(result.layerPattern, isNotNull);
        expect(result.layerPattern!.detected, 'clean_architecture');
        expect(result.layerPattern!.perFeature, isTrue);
        expect(
          result.layerPattern!.layers,
          containsAll(['data', 'domain', 'presentation']),
        );
      });
    });

    group('sample_riverpod_project (feature-first)', () {
      late StructureAnalyzer analyzer;

      setUp(() {
        analyzer = StructureAnalyzer('test/fixtures/sample_riverpod_project');
      });

      test('detects feature-first organization', () {
        final result = analyzer.analyze();
        expect(result.organization, 'feature-first');
      });

      test('finds feature directories', () {
        final result = analyzer.analyze();
        expect(result.featureDirs, containsAll(['auth', 'profile']));
      });

      test('finds core in top-level dirs', () {
        final result = analyzer.analyze();
        expect(result.topLevelDirs, contains('core'));
      });
    });

    group('sample_monorepo (separate packages)', () {
      late StructureAnalyzer analyzer;

      setUp(() {
        analyzer = StructureAnalyzer('test/fixtures/sample_monorepo/app');
      });

      test('detects separate packages', () {
        final result = analyzer.analyze();
        expect(result.hasSeparatePackages, isTrue);
      });
    });

    group('error handling', () {
      test('returns unknown for nonexistent path', () {
        final analyzer = StructureAnalyzer('/nonexistent');
        final result = analyzer.analyze();
        expect(result.organization, 'unknown');
      });
    });
  });
}
