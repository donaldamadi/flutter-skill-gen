import 'dart:convert';
import 'dart:io';

import 'package:flutter_skill_gen/src/generators/facts_writer.dart';
import 'package:flutter_skill_gen/src/models/project_facts.dart';
import 'package:flutter_skill_gen/src/scanner/project_scanner.dart';
import 'package:flutter_skill_gen/src/utils/logger.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectScanner', () {
    group('sample_bloc_project (integration)', () {
      late ProjectScanner scanner;

      setUp(() {
        scanner = ProjectScanner(
          projectPath: 'test/fixtures/sample_bloc_project',
          logger: const Logger(),
        );
      });

      test('produces non-null ProjectFacts', () {
        final facts = scanner.scan();
        expect(facts, isNotNull);
      });

      test('extracts correct project name', () {
        final facts = scanner.scan()!;
        expect(facts.projectName, 'sample_bloc_app');
      });

      test('extracts SDK constraints', () {
        final facts = scanner.scan()!;
        expect(facts.dartSdk, '^3.5.0');
        expect(facts.flutterSdk, '>=3.24.0');
      });

      test('detects architecture and state management', () {
        final facts = scanner.scan()!;
        expect(facts.patterns.architecture, 'clean_architecture');
        expect(facts.patterns.stateManagement, 'bloc');
      });

      test('detects routing and DI', () {
        final facts = scanner.scan()!;
        expect(facts.patterns.routing, 'go_router');
        expect(facts.patterns.di, 'get_it_injectable');
      });

      test('detects API client and error handling', () {
        final facts = scanner.scan()!;
        expect(facts.patterns.apiClient, 'dio_retrofit');
        expect(facts.patterns.errorHandling, 'either_dartz');
      });

      test('detects model approach', () {
        final facts = scanner.scan()!;
        expect(facts.patterns.modelApproach, 'freezed');
      });

      test('detects feature-first organization', () {
        final facts = scanner.scan()!;
        expect(facts.structure.organization, 'feature-first');
        expect(
          facts.structure.featureDirs,
          containsAll(['auth', 'home', 'cart']),
        );
      });

      test('detects clean arch layers per feature', () {
        final facts = scanner.scan()!;
        expect(facts.structure.layerPattern, isNotNull);
        expect(facts.structure.layerPattern!.detected, 'clean_architecture');
        expect(facts.structure.layerPattern!.perFeature, isTrue);
      });

      test('detects testing infrastructure', () {
        final facts = scanner.scan()!;
        expect(facts.testing, isNotNull);
        expect(facts.testing!.mockingLibrary, 'mocktail');
      });

      test('computes complexity metrics', () {
        final facts = scanner.scan()!;
        expect(facts.complexity, isNotNull);
        expect(facts.complexity!.totalDartFiles, greaterThan(0));
        expect(facts.complexity!.totalFeatures, 3);
      });

      test('includes tool version and timestamp', () {
        final facts = scanner.scan()!;
        expect(facts.toolVersion, '0.4.0');
        expect(facts.generatedAt, isNotEmpty);
      });

      test('conventions include code samples', () {
        final facts = scanner.scan()!;
        expect(facts.conventions.samples, isNotEmpty);
      });

      group('evidence bundle', () {
        test('populates projectName and di style from patterns', () {
          final facts = scanner.scan()!;
          final evidence = facts.evidence!;
          expect(evidence.projectName, 'sample_bloc_app');
          expect(evidence.di.style, 'get_it_injectable');
        });

        test('emits one FeatureEvidence per detected feature', () {
          final facts = scanner.scan()!;
          final names = facts.evidence!.features.map((f) => f.name).toSet();
          expect(names, containsAll(['auth', 'home', 'cart']));
        });

        test('auth records clean-arch layers and BlocBuilder usage', () {
          final facts = scanner.scan()!;
          final auth = facts.evidence!.features.firstWhere(
            (f) => f.name == 'auth',
          );
          expect(
            auth.layersPresent,
            containsAll(['data', 'domain', 'presentation']),
          );
          expect(auth.layersAbsent, isEmpty);
          expect(auth.widgetUsage['BlocBuilder'], greaterThanOrEqualTo(1));
          expect(auth.path, 'lib/features/auth');
        });

        test('cart feature reports missing data/domain layers', () {
          final facts = scanner.scan()!;
          final cart = facts.evidence!.features.firstWhere(
            (f) => f.name == 'cart',
          );
          expect(cart.layersPresent, ['presentation']);
          expect(cart.layersAbsent, containsAll(['data', 'domain']));
        });

        test('detects centralized DI at lib/core/di/injection.dart', () {
          final facts = scanner.scan()!;
          expect(
            facts.evidence!.di.registrationFiles,
            contains('lib/core/di/injection.dart'),
          );
          // DI is centralized, not per-feature.
          expect(facts.evidence!.di.perFeature, isFalse);
        });

        test('file manifest contains every lib/ dart file', () {
          final facts = scanner.scan()!;
          final paths = facts.evidence!.fileManifest.allFilePaths;
          expect(paths, contains('lib/core/di/injection.dart'));
          expect(
            paths,
            contains('lib/features/auth/presentation/bloc/auth_bloc.dart'),
          );
        });

        test('class manifest includes AuthBloc', () {
          final facts = scanner.scan()!;
          expect(
            facts.evidence!.fileManifest.allClassNames,
            contains('AuthBloc'),
          );
        });

        test('known file patterns reflect actual files', () {
          final facts = scanner.scan()!;
          final patterns = facts.evidence!.knownFilePatterns;
          expect(patterns, contains('*_bloc.dart'));
          expect(patterns, contains('*_state.dart'));
          expect(patterns, contains('*_event.dart'));
          expect(patterns, contains('*_page.dart'));
          // No cubit files in this fixture.
          expect(patterns, isNot(contains('*_cubit.dart')));
        });
      });
    });

    group('sample_riverpod_project (integration)', () {
      test('detects riverpod patterns', () {
        final scanner = ProjectScanner(
          projectPath: 'test/fixtures/sample_riverpod_project',
          logger: const Logger(),
        );
        final facts = scanner.scan()!;
        expect(facts.patterns.stateManagement, 'riverpod');
        expect(facts.patterns.routing, 'auto_route');
        expect(facts.patterns.di, 'riverpod');
        expect(facts.patterns.errorHandling, 'either_fpdart');
      });
    });

    group('error handling', () {
      test('returns null for nonexistent path', () {
        final scanner = ProjectScanner(
          projectPath: '/nonexistent/path',
          logger: const Logger(),
        );
        expect(scanner.scan(), isNull);
      });

      test('returns null for path without pubspec', () {
        final scanner = ProjectScanner(
          projectPath: 'test/fixtures',
          logger: const Logger(),
        );
        expect(scanner.scan(), isNull);
      });
    });
  });

  group('FactsWriter', () {
    test('writes valid JSON to disk', () {
      final scanner = ProjectScanner(
        projectPath: 'test/fixtures/sample_bloc_project',
        logger: const Logger(),
      );
      final facts = scanner.scan()!;

      final tmpDir = Directory.systemTemp.createTempSync(
        'flutter_skill_gen_test_',
      );
      try {
        final outputPath = FactsWriter.write(facts, outputDir: tmpDir.path);

        final file = File(outputPath);
        expect(file.existsSync(), isTrue);

        final content = file.readAsStringSync();
        final json = jsonDecode(content) as Map<String, dynamic>;
        expect(json['project_name'], 'sample_bloc_app');
        expect(json['tool_version'], '0.4.0');
        expect(json['dependencies'], isA<Map<String, dynamic>>());
        expect(json['structure'], isA<Map<String, dynamic>>());
        expect(json['patterns'], isA<Map<String, dynamic>>());
        expect(json['conventions'], isA<Map<String, dynamic>>());
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    });

    test('roundtrips through JSON serialization', () {
      final scanner = ProjectScanner(
        projectPath: 'test/fixtures/sample_bloc_project',
        logger: const Logger(),
      );
      final facts = scanner.scan()!;
      final json = facts.toJson();
      final restored = ProjectFacts.fromJson(json);

      expect(restored.projectName, facts.projectName);
      expect(restored.patterns.architecture, facts.patterns.architecture);
      expect(restored.patterns.stateManagement, facts.patterns.stateManagement);
      expect(restored.structure.organization, facts.structure.organization);
      expect(restored.structure.featureDirs, facts.structure.featureDirs);
    });
  });
}
