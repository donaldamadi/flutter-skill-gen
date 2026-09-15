import 'package:flutter_skill_gen/src/verifier/claim_extractors.dart';
import 'package:test/test.dart';

void main() {
  group('extractFilePathClaims', () {
    test('extracts a lib/ path from prose', () {
      final claims = extractFilePathClaims(
        'Look at lib/features/auth/auth_bloc.dart for details.',
      );
      expect(claims, hasLength(1));
      expect(claims.single.value, 'lib/features/auth/auth_bloc.dart');
      expect(claims.single.lineNumber, 1);
    });

    test('extracts a lib/ path from inline code', () {
      final claims = extractFilePathClaims(
        'The bloc lives in `lib/features/auth/bloc/auth_bloc.dart`.',
      );
      expect(claims.single.value, 'lib/features/auth/bloc/auth_bloc.dart');
    });

    test('extracts a lib/ path from a markdown link target', () {
      final claims = extractFilePathClaims(
        '[auth_bloc](lib/features/auth/auth_bloc.dart)',
      );
      expect(claims.single.value, 'lib/features/auth/auth_bloc.dart');
    });

    test('records accurate line numbers across multi-line input', () {
      final claims = extractFilePathClaims('''
First paragraph.
See lib/a.dart.
And also lib/b.dart.
''');
      expect(claims.map((c) => c.lineNumber), [2, 3]);
      expect(claims.map((c) => c.value), ['lib/a.dart', 'lib/b.dart']);
    });

    test('does NOT extract paths embedded in URLs', () {
      final claims = extractFilePathClaims(
        'See https://github.com/user/repo/blob/main/lib/foo.dart',
      );
      expect(claims, isEmpty);
    });

    test('does NOT extract paths preceded by a word char (e.g. mylib/)', () {
      final claims = extractFilePathClaims('mylib/foo.dart');
      expect(claims, isEmpty);
    });

    test('returns empty list when no dart paths are present', () {
      final claims = extractFilePathClaims('# Heading\n\nNothing here.');
      expect(claims, isEmpty);
    });
  });

  group('extractGlobPatternClaims', () {
    test('extracts *_bloc.dart style patterns', () {
      final claims = extractGlobPatternClaims(
        'Files follow `*_bloc.dart`, `*_state.dart`, `*_event.dart`.',
      );
      expect(
        claims.map((c) => c.value),
        containsAll(['*_bloc.dart', '*_state.dart', '*_event.dart']),
      );
    });

    test('does NOT match plain *.dart (needs underscore suffix)', () {
      final claims = extractGlobPatternClaims('All files match *.dart.');
      expect(claims, isEmpty);
    });

    test('records line numbers', () {
      final claims = extractGlobPatternClaims(
        'line 1\nUse *_cubit.dart here.\nend',
      );
      expect(claims.single.lineNumber, 2);
      expect(claims.single.value, '*_cubit.dart');
    });
  });

  group('extractClassNameClaims', () {
    test('extracts PascalCase tokens ending in project suffixes', () {
      final claims = extractClassNameClaims(
        'The `AuthBloc`, `LoginCubit`, and `UserRepositoryImpl` classes.',
      );
      expect(
        claims.map((c) => c.value),
        containsAll(['AuthBloc', 'LoginCubit', 'UserRepositoryImpl']),
      );
    });

    test('whitelists framework classes that end in a project suffix', () {
      final claims = extractClassNameClaims(
        'Uses `StateNotifier`, `ChangeNotifier`, and `AsyncNotifier`.',
      );
      expect(claims, isEmpty);
    });

    test('does NOT extract plain suffixes as standalone names', () {
      // `Bloc` and `Cubit` alone are base classes, not project-specific.
      final claims = extractClassNameClaims('A Bloc holds state.');
      expect(claims, isEmpty);
    });

    test('does NOT extract non-suffix PascalCase identifiers', () {
      final claims = extractClassNameClaims(
        'Widgets like `BlocBuilder` and `Scaffold` are common.',
      );
      expect(claims, isEmpty);
    });

    test('extracts class names from code-fence declarations', () {
      final claims = extractClassNameClaims('''
```dart
class AuthBloc extends Bloc<AuthEvent, AuthState> { }
```
''');
      expect(
        claims.map((c) => c.value),
        containsAll(['AuthBloc', 'AuthEvent', 'AuthState']),
      );
    });
  });

  group('extractDiPerFeatureClaims', () {
    test('catches "per-feature DI" phrasing', () {
      final claims = extractDiPerFeatureClaims(
        'The project uses per-feature DI with auth_injection.dart.',
      );
      expect(claims, hasLength(1));
    });

    test('catches "each feature registers its own dependencies"', () {
      final claims = extractDiPerFeatureClaims(
        'Each feature registers its own dependencies in a module.',
      );
      expect(claims, hasLength(1));
    });

    test('catches "feature-local DI"', () {
      final claims = extractDiPerFeatureClaims(
        'Prefer feature-local DI over a global service locator.',
      );
      expect(claims, hasLength(1));
    });

    group('negated statements are not claims', () {
      // Sentences taken verbatim from a real generated skill file.
      // Each one tells the reader the project does NOT use per-feature
      // DI, which is exactly what the evidence says — flagging them
      // punished the model for being correct, and taught writers to
      // avoid saying the true thing.

      test('"rather than per-feature injection"', () {
        final claims = extractDiPerFeatureClaims(
          'DI is centralized through Riverpod providers rather than '
          'per-feature injection files.',
        );
        expect(claims, isEmpty);
      });

      test('"Don\'t create a per-feature DI file"', () {
        final claims = extractDiPerFeatureClaims(
          "- Don't create a per-feature DI/injection file for loans "
          'providers.',
        );
        expect(claims, isEmpty);
      });

      test('"no per-feature DI"', () {
        final claims = extractDiPerFeatureClaims(
          'This project has no per-feature DI; providers are declared '
          'where they are used.',
        );
        expect(claims, isEmpty);
      });

      test('"instead of feature-local DI"', () {
        final claims = extractDiPerFeatureClaims(
          'Register services centrally instead of feature-local DI.',
        );
        expect(claims, isEmpty);
      });

      test('"avoid per-feature dependency injection"', () {
        final claims = extractDiPerFeatureClaims(
          'Avoid per-feature dependency injection in this codebase.',
        );
        expect(claims, isEmpty);
      });

      test('"never registered per-feature"', () {
        final claims = extractDiPerFeatureClaims(
          'Dependencies are never registered per-feature here.',
        );
        expect(claims, isEmpty);
      });

      test('a negation in an earlier sentence does not excuse a later '
          'claim', () {
        // Suppression is scoped to the clause, so a stray "not" earlier
        // on the line cannot smuggle a real claim past the verifier.
        final claims = extractDiPerFeatureClaims(
          'This is not a monorepo. Each feature registers its own '
          'dependencies in a module.',
        );
        expect(claims, hasLength(1));
      });
    });

    test('does NOT catch generic DI mentions', () {
      final claims = extractDiPerFeatureClaims(
        'The project uses GetIt with injectable for DI.',
      );
      expect(claims, isEmpty);
    });

    test('records one claim per matching line only', () {
      final claims = extractDiPerFeatureClaims(
        'per-feature DI is used; per-feature dependency injection is used.',
      );
      expect(claims, hasLength(1));
    });
  });
}
