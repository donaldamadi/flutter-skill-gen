import 'dart:io';

import 'package:flutter_skill_gen/src/analyzers/pattern_detector.dart';
import 'package:flutter_skill_gen/src/models/dependency_info.dart';
import 'package:flutter_skill_gen/src/models/structure_info.dart';
import 'package:test/test.dart';

void main() {
  group('PatternDetector', () {
    group('BLoC + Clean Architecture project', () {
      late PatternDetector detector;

      setUp(() {
        detector = PatternDetector(
          projectPath: Directory.systemTemp.path,
          dependencies: const DependencyInfo(
            stateManagement: ['flutter_bloc', 'bloc'],
            routing: ['go_router'],
            di: ['get_it', 'injectable'],
            networking: ['dio', 'retrofit'],
            localStorage: ['hive', 'hive_flutter'],
            codeGeneration: ['build_runner', 'freezed', 'json_serializable'],
            testing: ['bloc_test', 'mocktail'],
            other: ['equatable', 'dartz', 'intl'],
          ),
          structure: const StructureInfo(
            organization: 'feature-first',
            topLevelDirs: ['core', 'features', 'shared'],
            featureDirs: ['auth', 'home', 'cart'],
            layerPattern: LayerPattern(
              detected: 'clean_architecture',
              layers: ['data', 'domain', 'presentation'],
              perFeature: true,
            ),
          ),
        );
      });

      test('detects clean architecture', () {
        final result = detector.detect();
        expect(result.architecture, 'clean_architecture');
      });

      test('detects bloc state management', () {
        final result = detector.detect();
        expect(result.stateManagement, 'bloc');
      });

      test('detects go_router routing', () {
        final result = detector.detect();
        expect(result.routing, 'go_router');
      });

      test('detects get_it + injectable DI', () {
        final result = detector.detect();
        expect(result.di, 'get_it_injectable');
      });

      test('detects dio + retrofit API client', () {
        final result = detector.detect();
        expect(result.apiClient, 'dio_retrofit');
      });

      test('detects dartz error handling', () {
        final result = detector.detect();
        expect(result.errorHandling, 'either_dartz');
      });

      test('detects freezed model approach', () {
        final result = detector.detect();
        expect(result.modelApproach, 'freezed');
      });
    });

    group('Riverpod project', () {
      late PatternDetector detector;

      setUp(() {
        detector = PatternDetector(
          projectPath: Directory.systemTemp.path,
          dependencies: const DependencyInfo(
            stateManagement: [
              'flutter_riverpod',
              'hooks_riverpod',
              'riverpod_annotation',
            ],
            routing: ['auto_route'],
            networking: ['dio'],
            localStorage: ['shared_preferences'],
            codeGeneration: ['build_runner', 'freezed', 'riverpod_generator'],
            other: ['fpdart'],
          ),
          structure: const StructureInfo(
            organization: 'feature-first',
            topLevelDirs: ['core', 'features', 'shared'],
            featureDirs: ['auth', 'profile'],
          ),
        );
      });

      test('detects riverpod state management', () {
        final result = detector.detect();
        expect(result.stateManagement, 'riverpod');
      });

      test('detects auto_route routing', () {
        final result = detector.detect();
        expect(result.routing, 'auto_route');
      });

      test('detects riverpod as DI', () {
        final result = detector.detect();
        expect(result.di, 'riverpod');
      });

      test('detects dio API client', () {
        final result = detector.detect();
        expect(result.apiClient, 'dio');
      });

      test('detects fpdart error handling', () {
        final result = detector.detect();
        expect(result.errorHandling, 'either_fpdart');
      });

      test('detects freezed model approach', () {
        final result = detector.detect();
        expect(result.modelApproach, 'freezed');
      });
    });

    group('minimal project with no deps', () {
      test('returns nulls for all patterns', () {
        final tempDir = Directory.systemTemp.createTempSync(
          'flutter_skill_gen_pattern_test_',
        );
        try {
          final detector = PatternDetector(
            projectPath: tempDir.path,
            dependencies: const DependencyInfo(),
            structure: const StructureInfo(organization: 'flat'),
          );
          final result = detector.detect();
          expect(result.architecture, isNull);
          expect(result.stateManagement, isNull);
          expect(result.routing, isNull);
          expect(result.di, isNull);
          expect(result.apiClient, isNull);
          expect(result.errorHandling, isNull);
          expect(result.modelApproach, isNull);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });
    });

    group('edge cases', () {
      test('provider-only project detects provider', () {
        final detector = PatternDetector(
          projectPath: Directory.systemTemp.path,
          dependencies: const DependencyInfo(stateManagement: ['provider']),
          structure: const StructureInfo(organization: 'flat'),
        );
        final result = detector.detect();
        expect(result.stateManagement, 'provider');
      });

      test('getx project detects getx', () {
        final detector = PatternDetector(
          projectPath: Directory.systemTemp.path,
          dependencies: const DependencyInfo(stateManagement: ['get']),
          structure: const StructureInfo(organization: 'flat'),
        );
        final result = detector.detect();
        expect(result.stateManagement, 'getx');
      });

      test('get_it without injectable detects get_it', () {
        final detector = PatternDetector(
          projectPath: Directory.systemTemp.path,
          dependencies: const DependencyInfo(di: ['get_it']),
          structure: const StructureInfo(organization: 'flat'),
        );
        final result = detector.detect();
        expect(result.di, 'get_it');
      });

      test('json_serializable without freezed', () {
        final detector = PatternDetector(
          projectPath: Directory.systemTemp.path,
          dependencies: const DependencyInfo(
            codeGeneration: ['json_serializable'],
            other: ['json_annotation'],
          ),
          structure: const StructureInfo(organization: 'flat'),
        );
        final result = detector.detect();
        expect(result.modelApproach, 'json_serializable');
      });

      test('http package as API client', () {
        final detector = PatternDetector(
          projectPath: Directory.systemTemp.path,
          dependencies: const DependencyInfo(networking: ['http']),
          structure: const StructureInfo(organization: 'flat'),
        );
        final result = detector.detect();
        expect(result.apiClient, 'http');
      });
    });
  });
}
