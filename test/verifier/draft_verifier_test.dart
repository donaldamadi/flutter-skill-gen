import 'package:flutter_skill_gen/src/models/evidence_bundle.dart';
import 'package:flutter_skill_gen/src/verifier/draft_verifier.dart';
import 'package:test/test.dart';

EvidenceBundle _bundle({
  List<String> filePaths = const [],
  List<String> classNames = const [],
  List<String> globs = const [],
  bool diPerFeature = false,
  List<String> registrationFiles = const [],
}) {
  return EvidenceBundle(
    projectName: 'demo',
    features: const [],
    di: DiEvidence(
      style: 'get_it_injectable',
      registrationFiles: registrationFiles,
      perFeature: diPerFeature,
    ),
    globalWidgetUsage: const {},
    knownFilePatterns: globs,
    fileManifest: FileManifest(
      allFilePaths: filePaths,
      allClassNames: classNames,
    ),
  );
}

void main() {
  group('DraftVerifier — no violations', () {
    test('returns input unchanged when every claim matches evidence', () {
      final verifier = DraftVerifier(
        evidence: _bundle(
          filePaths: const ['lib/features/auth/auth_bloc.dart'],
          classNames: const ['AuthBloc'],
          globs: const ['*_bloc.dart'],
        ),
      );

      const draft =
          'AuthBloc is at lib/features/auth/auth_bloc.dart\n'
          'Files follow *_bloc.dart.\n';

      final result = verifier.verify(draft);

      expect(result.violations, isEmpty);
      expect(result.hasViolations, isFalse);
      expect(result.output, draft);
    });

    test('whitelisted globs never trigger violations', () {
      final verifier = DraftVerifier(evidence: _bundle());
      final result = verifier.verify(
        'Tests follow `*_test.dart`, codegen emits `*.g.dart`.',
      );
      expect(result.violations, isEmpty);
    });
  });

  group('DraftVerifier — violation detection', () {
    test('flags a file path that isn\'t in the manifest', () {
      final verifier = DraftVerifier(
        evidence: _bundle(filePaths: const ['lib/real.dart']),
      );
      final result = verifier.verify('Draft: lib/fake.dart exists.');
      expect(result.violations, hasLength(1));
      expect(result.violations.single.kind, ViolationKind.unknownFilePath);
      expect(result.violations.single.claim, 'lib/fake.dart');
    });

    test('flags a class name not declared under lib/', () {
      final verifier = DraftVerifier(
        evidence: _bundle(classNames: const ['AuthBloc']),
      );
      final result = verifier.verify(
        'The project defines `AuthBloc` and `LoginCubit`.',
      );
      expect(result.violations, hasLength(1));
      expect(result.violations.single.kind, ViolationKind.unknownClassName);
      expect(result.violations.single.claim, 'LoginCubit');
    });

    test('flags a glob pattern that matches no lib/ files', () {
      final verifier = DraftVerifier(
        evidence: _bundle(globs: const ['*_bloc.dart']),
      );
      final result = verifier.verify('Files follow `*_cubit.dart`.');
      expect(result.violations, hasLength(1));
      expect(result.violations.single.kind, ViolationKind.unknownGlobPattern);
      expect(result.violations.single.claim, '*_cubit.dart');
    });

    test('flags a per-feature DI claim when evidence is centralized', () {
      final verifier = DraftVerifier(
        evidence: _bundle(
          filePaths: const ['lib/core/di/injection.dart'],
          diPerFeature: false,
        ),
      );
      final result = verifier.verify('The project uses per-feature DI.');
      expect(result.violations, hasLength(1));
      expect(
        result.violations.single.kind,
        ViolationKind.falseDiPerFeatureClaim,
      );
    });

    test('does NOT flag per-feature DI claim when evidence confirms it', () {
      final verifier = DraftVerifier(evidence: _bundle(diPerFeature: true));
      final result = verifier.verify('The project uses per-feature DI.');
      expect(result.violations, isEmpty);
    });

    test('violations are sorted by line number', () {
      final verifier = DraftVerifier(evidence: _bundle());
      final result = verifier.verify('''
line 1
mention lib/b.dart on line 2
line 3
and lib/a.dart on line 4
''');
      expect(result.violations.map((v) => v.lineNumber), [2, 4]);
    });
  });

  group('VerifierMode.annotate', () {
    test('appends [UNVERIFIED: ...] to violating lines only', () {
      final verifier = DraftVerifier(evidence: _bundle());
      final result = verifier.verify(
        'good line\nmention lib/fake.dart here\nclean line',
      );
      final lines = result.output.split('\n');
      expect(lines[0], 'good line');
      expect(lines[1], contains('<!-- [UNVERIFIED: lib/fake.dart] -->'));
      expect(lines[2], 'clean line');
    });

    test('dedupes multiple violations on the same line', () {
      final verifier = DraftVerifier(evidence: _bundle());
      final result = verifier.verify('lib/a.dart and lib/a.dart');
      // Two claims, same value — annotation should list it once.
      expect(
        RegExp('lib/a.dart').allMatches(result.output).length,
        greaterThanOrEqualTo(2), // the draft itself still has both
      );
      expect(result.violations, hasLength(2));
      // Single annotation comment on the single line.
      expect(RegExp('UNVERIFIED').allMatches(result.output).length, 1);
    });
  });

  group('VerifierMode.strip', () {
    test('removes lines that contain violations', () {
      final verifier = DraftVerifier(
        evidence: _bundle(),
        mode: VerifierMode.strip,
      );
      final result = verifier.verify(
        'keep this\nmention lib/fake.dart\nkeep this too',
      );
      expect(result.output, 'keep this\nkeep this too');
      expect(result.violations, hasLength(1));
    });

    test('preserves draft entirely when no violations found', () {
      final verifier = DraftVerifier(
        evidence: _bundle(filePaths: const ['lib/real.dart']),
        mode: VerifierMode.strip,
      );
      final result = verifier.verify('only lib/real.dart is mentioned');
      expect(result.output, 'only lib/real.dart is mentioned');
    });
  });

  group('VerifierMode.fatal', () {
    test('returns draft unchanged and exposes violations', () {
      final verifier = DraftVerifier(
        evidence: _bundle(),
        mode: VerifierMode.fatal,
      );
      const draft = 'reference to lib/fake.dart';
      final result = verifier.verify(draft);
      expect(result.output, draft);
      expect(result.hasViolations, isTrue);
      expect(result.violations.single.claim, 'lib/fake.dart');
    });
  });

  group('DraftVerifier — real-world bug-report scenarios', () {
    test('centralized-DI project: AI hallucinating per-feature DI', () {
      // Evidence shows one central injection.dart and a single bloc.
      final verifier = DraftVerifier(
        evidence: _bundle(
          filePaths: const [
            'lib/core/di/injection.dart',
            'lib/features/auth/presentation/bloc/auth_bloc.dart',
          ],
          classNames: const ['AuthBloc'],
          globs: const ['*_bloc.dart'],
          registrationFiles: const ['lib/core/di/injection.dart'],
        ),
      );

      const hallucinatedDraft = '''
# Conventions

The project uses per-feature DI with `*_injection.dart` files.
Each feature has `LoginCubit`, `HomeCubit`, and `AuthRepositoryImpl`.
The real auth bloc lives at `lib/features/auth/presentation/bloc/auth_bloc.dart`.
''';

      final result = verifier.verify(hallucinatedDraft);

      // Collect the kinds flagged.
      final kinds = result.violations.map((v) => v.kind).toSet();
      expect(kinds, contains(ViolationKind.falseDiPerFeatureClaim));
      expect(kinds, contains(ViolationKind.unknownGlobPattern));
      expect(kinds, contains(ViolationKind.unknownClassName));
      // The real file path is NOT flagged.
      expect(kinds, isNot(contains(ViolationKind.unknownFilePath)));

      // Specific hallucinated classes.
      final claims = result.violations.map((v) => v.claim).toSet();
      expect(claims, containsAll(['LoginCubit', 'HomeCubit']));
      expect(claims, contains('AuthRepositoryImpl'));
      // *_injection.dart isn't in known globs.
      expect(claims, contains('*_injection.dart'));
    });
  });
}
