import 'package:flutter_skill_gen/src/analyzers/pubspec_analyzer.dart';
import 'package:test/test.dart';

void main() {
  group('PubspecAnalyzer', () {
    group('sample_bloc_project', () {
      late PubspecAnalyzer analyzer;

      setUp(() {
        analyzer = PubspecAnalyzer('test/fixtures/sample_bloc_project');
        expect(analyzer.load(), isTrue);
      });

      test('extracts project name', () {
        expect(analyzer.projectName, 'sample_bloc_app');
      });

      test('extracts project description', () {
        expect(
          analyzer.projectDescription,
          contains('Clean Architecture and BLoC'),
        );
      });

      test('extracts dart SDK constraint', () {
        expect(analyzer.dartSdk, '^3.5.0');
      });

      test('extracts flutter SDK constraint', () {
        expect(analyzer.flutterSdk, '>=3.24.0');
      });

      test('categorizes state management dependencies', () {
        final deps = analyzer.analyzeDependencies();
        expect(deps.stateManagement, containsAll(['flutter_bloc', 'bloc']));
      });

      test('categorizes routing dependencies', () {
        final deps = analyzer.analyzeDependencies();
        expect(deps.routing, contains('go_router'));
      });

      test('categorizes DI dependencies', () {
        final deps = analyzer.analyzeDependencies();
        expect(deps.di, containsAll(['get_it', 'injectable']));
      });

      test('categorizes networking dependencies', () {
        final deps = analyzer.analyzeDependencies();
        expect(deps.networking, containsAll(['dio', 'retrofit']));
      });

      test('categorizes local storage dependencies', () {
        final deps = analyzer.analyzeDependencies();
        expect(deps.localStorage, containsAll(['hive', 'hive_flutter']));
      });

      test('categorizes code generation dependencies', () {
        final deps = analyzer.analyzeDependencies();
        expect(
          deps.codeGeneration,
          containsAll(['build_runner', 'freezed', 'json_serializable']),
        );
      });

      test('categorizes testing dependencies', () {
        final deps = analyzer.analyzeDependencies();
        expect(deps.testing, containsAll(['bloc_test', 'mocktail']));
      });

      test('puts uncategorized deps in other', () {
        final deps = analyzer.analyzeDependencies();
        expect(deps.other, containsAll(['equatable', 'dartz', 'intl']));
      });

      test('excludes flutter SDK from all categories', () {
        final deps = analyzer.analyzeDependencies();
        final allCategorized = [
          ...deps.stateManagement,
          ...deps.routing,
          ...deps.di,
          ...deps.networking,
          ...deps.localStorage,
          ...deps.codeGeneration,
          ...deps.testing,
          ...deps.other,
        ];
        expect(allCategorized, isNot(contains('flutter')));
      });
    });

    group('sample_riverpod_project', () {
      late PubspecAnalyzer analyzer;

      setUp(() {
        analyzer = PubspecAnalyzer('test/fixtures/sample_riverpod_project');
        expect(analyzer.load(), isTrue);
      });

      test('detects riverpod as state management', () {
        final deps = analyzer.analyzeDependencies();
        expect(
          deps.stateManagement,
          containsAll([
            'flutter_riverpod',
            'hooks_riverpod',
            'riverpod_annotation',
          ]),
        );
      });

      test('detects auto_route as routing', () {
        final deps = analyzer.analyzeDependencies();
        expect(deps.routing, contains('auto_route'));
      });

      test('detects fpdart in other', () {
        final deps = analyzer.analyzeDependencies();
        expect(deps.other, contains('fpdart'));
      });

      test('detects shared_preferences as local storage', () {
        final deps = analyzer.analyzeDependencies();
        expect(deps.localStorage, contains('shared_preferences'));
      });
    });

    group('error handling', () {
      test('returns false for nonexistent path', () {
        final analyzer = PubspecAnalyzer('/nonexistent/path');
        expect(analyzer.load(), isFalse);
      });

      test('returns false for directory without pubspec', () {
        final analyzer = PubspecAnalyzer('test/fixtures');
        expect(analyzer.load(), isFalse);
      });
    });
  });
}
