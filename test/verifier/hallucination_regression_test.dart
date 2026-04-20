import 'package:flutter_skill_gen/src/scanner/project_scanner.dart';
import 'package:flutter_skill_gen/src/utils/logger.dart';
import 'package:flutter_skill_gen/src/verifier/draft_verifier.dart';
import 'package:test/test.dart';

/// Mirrors the shape of the real-world bug report: a drafted SKILL.md
/// that claims per-feature DI, references cubit classes the project
/// doesn't have, and points at files that don't exist.
const _hallucinatedDraft = '''
# sample_bloc_app

## State Management
Each feature exposes a dedicated Cubit — for example `LoginCubit`
and `HomeCubit` — driving the UI from business logic. State classes
like `LoginState` are hand-written alongside each Cubit.

## Dependency Injection
The project uses per-feature DI: every feature registers its own
services via a `*_injection.dart` file under its folder.
Wiring lives in lib/features/auth/auth_injection.dart.

## File Patterns
Presentation layer files follow `*_cubit.dart` and `*_page.dart`.
''';

void main() {
  group('Hallucination regression (sample_bloc_project)', () {
    late DraftVerifier verifier;

    setUp(() {
      final scanner = ProjectScanner(
        projectPath: 'test/fixtures/sample_bloc_project',
        logger: const Logger(),
      );
      final facts = scanner.scan()!;
      verifier = DraftVerifier(evidence: facts.evidence!);
    });

    test('flags hallucinated Cubit classes absent from the codebase', () {
      final result = verifier.verify(_hallucinatedDraft);
      final classClaims = result.violations
          .where((v) => v.kind == ViolationKind.unknownClassName)
          .map((v) => v.claim)
          .toSet();
      expect(classClaims, containsAll(['LoginCubit', 'HomeCubit']));
    });

    test('flags per-feature DI prose as contradicting centralized DI', () {
      final result = verifier.verify(_hallucinatedDraft);
      expect(
        result.violations.any(
          (v) => v.kind == ViolationKind.falseDiPerFeatureClaim,
        ),
        isTrue,
        reason:
            'evidence.di.per_feature is false — prose claiming per-feature '
            'DI must be flagged',
      );
    });

    test('flags the hallucinated *_injection.dart glob', () {
      final result = verifier.verify(_hallucinatedDraft);
      final globClaims = result.violations
          .where((v) => v.kind == ViolationKind.unknownGlobPattern)
          .map((v) => v.claim)
          .toSet();
      expect(globClaims, contains('*_injection.dart'));
      // *_cubit.dart should also be flagged: the fixture has no cubits.
      expect(globClaims, contains('*_cubit.dart'));
      // *_page.dart is a real pattern in the fixture — NOT flagged.
      expect(globClaims, isNot(contains('*_page.dart')));
    });

    test('flags the fake lib/features/auth/auth_injection.dart path', () {
      final result = verifier.verify(_hallucinatedDraft);
      final pathClaims = result.violations
          .where((v) => v.kind == ViolationKind.unknownFilePath)
          .map((v) => v.claim)
          .toSet();
      expect(pathClaims, contains('lib/features/auth/auth_injection.dart'));
    });

    test('strip mode purges every violating line from the draft', () {
      final stripVerifier = DraftVerifier(
        evidence: verifier.evidence,
        mode: VerifierMode.strip,
      );
      final result = stripVerifier.verify(_hallucinatedDraft);
      expect(result.output, isNot(contains('LoginCubit')));
      expect(result.output, isNot(contains('HomeCubit')));
      expect(result.output, isNot(contains('per-feature DI')));
      expect(result.output, isNot(contains('*_injection.dart')));
      expect(result.output, isNot(contains('auth_injection.dart')));
      // Non-violating prose survives.
      expect(result.output, contains('# sample_bloc_app'));
      expect(result.output, contains('## State Management'));
    });

    test('annotate mode appends UNVERIFIED markers without losing prose', () {
      final annotateVerifier = DraftVerifier(
        evidence: verifier.evidence,
        mode: VerifierMode.annotate,
      );
      final result = annotateVerifier.verify(_hallucinatedDraft);
      expect(result.output, contains('UNVERIFIED'));
      // The original hallucinated content is still present alongside markers.
      expect(result.output, contains('LoginCubit'));
      expect(result.output, contains('per-feature DI'));
    });

    test('a draft grounded in evidence passes with zero violations', () {
      const groundedDraft = '''
# sample_bloc_app

The authentication feature exposes an `AuthBloc` at
lib/features/auth/presentation/bloc/auth_bloc.dart.

Dependencies are registered centrally via
lib/core/di/injection.dart; each class is annotated with
`@injectable` and wired by `configureDependencies()`.

Files follow the `*_bloc.dart`, `*_state.dart`, and `*_event.dart`
conventions.
''';
      final result = verifier.verify(groundedDraft);
      expect(result.violations, isEmpty);
      expect(result.output, equals(groundedDraft));
    });
  });
}
