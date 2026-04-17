import 'package:flutter_skill_gen/src/analyzers/code_sampler.dart';
import 'package:test/test.dart';

void main() {
  group('CodeSampler', () {
    group('sample_bloc_project', () {
      late CodeSampler sampler;

      setUp(() {
        sampler = CodeSampler('test/fixtures/sample_bloc_project');
      });

      test('detects snake_case file naming', () {
        final result = sampler.analyze();
        expect(result.naming, isNotNull);
        expect(result.naming!.files, 'snake_case');
      });

      test('detects PascalCase class naming', () {
        final result = sampler.analyze();
        expect(result.naming!.classes, 'PascalCase');
      });

      test('detects BLoC event naming convention', () {
        final result = sampler.analyze();
        expect(result.naming!.blocEvents, 'PascalCase_suffixed_Event');
      });

      test('detects BLoC state naming convention', () {
        final result = sampler.analyze();
        expect(result.naming!.blocStates, 'PascalCase_suffixed_State');
      });

      test('detects import style', () {
        final result = sampler.analyze();
        expect(result.imports, isNotNull);
        expect(result.imports!.style, anyOf('relative', 'package', 'mixed'));
      });

      test('collects code samples', () {
        final result = sampler.analyze();
        expect(result.samples, isNotEmpty);
      });

      test('collects bloc example sample', () {
        final result = sampler.analyze();
        final blocSample = result.samples.where(
          (s) => s.type == 'bloc_example',
        );
        expect(blocSample, isNotEmpty);
        expect(blocSample.first.file, contains('auth_bloc.dart'));
        expect(blocSample.first.snippet, contains('AuthBloc'));
      });

      test('collects repository example sample', () {
        final result = sampler.analyze();
        final repoSample = result.samples.where(
          (s) => s.type == 'repository_example',
        );
        expect(repoSample, isNotEmpty);
        expect(repoSample.first.snippet, contains('AuthRepository'));
      });

      test('collects usecase example sample', () {
        final result = sampler.analyze();
        final usecaseSample = result.samples.where(
          (s) => s.type == 'usecase_example',
        );
        expect(usecaseSample, isNotEmpty);
        expect(usecaseSample.first.snippet, contains('LoginUsecase'));
      });

      test('limits samples to at most 5', () {
        final result = sampler.analyze();
        expect(result.samples.length, lessThanOrEqualTo(5));
      });
    });

    group('error handling', () {
      test('returns empty conventions for nonexistent path', () {
        final sampler = CodeSampler('/nonexistent');
        final result = sampler.analyze();
        expect(result.naming, isNull);
        expect(result.imports, isNull);
        expect(result.samples, isEmpty);
      });
    });
  });
}
