import 'dart:convert';

import 'package:flutter_skill_gen/src/generators/skill_generator.dart';
import 'package:flutter_skill_gen/src/models/convention_info.dart';
import 'package:flutter_skill_gen/src/models/dependency_info.dart';
import 'package:flutter_skill_gen/src/models/evidence_bundle.dart';
import 'package:flutter_skill_gen/src/models/pattern_info.dart';
import 'package:flutter_skill_gen/src/models/project_facts.dart';
import 'package:flutter_skill_gen/src/models/structure_info.dart';
import 'package:flutter_skill_gen/src/verifier/draft_verifier.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:test/test.dart';

ProjectFacts _factsWithEvidence() {
  return const ProjectFacts(
    projectName: 'demo_app',
    dependencies: DependencyInfo(stateManagement: ['flutter_bloc']),
    structure: StructureInfo(
      organization: 'feature-first',
      featureDirs: ['auth'],
    ),
    patterns: PatternInfo(
      architecture: 'clean_architecture',
      stateManagement: 'bloc',
      di: 'get_it_injectable',
    ),
    conventions: ConventionInfo(),
    evidence: EvidenceBundle(
      projectName: 'demo_app',
      features: [
        FeatureEvidence(
          name: 'auth',
          path: 'lib/features/auth',
          layersPresent: ['data', 'domain', 'presentation'],
          stateClasses: [
            ClassReference(
              name: 'AuthBloc',
              file: 'lib/features/auth/presentation/bloc/auth_bloc.dart',
            ),
          ],
        ),
      ],
      di: DiEvidence(
        style: 'get_it_injectable',
        registrationFiles: ['lib/core/di/injection.dart'],
      ),
      knownFilePatterns: ['*_bloc.dart', '*_state.dart'],
      fileManifest: FileManifest(
        allFilePaths: [
          'lib/core/di/injection.dart',
          'lib/features/auth/presentation/bloc/auth_bloc.dart',
        ],
        allClassNames: ['AuthBloc'],
      ),
    ),
    generatedAt: '2026-04-20T00:00:00Z',
    toolVersion: '0.2.0',
  );
}

const _hallucinatedDraft = '''
# demo_app

## Overview
A hallucinated SKILL.md.

## State Management
Each feature has a `LoginCubit` and a `HomeCubit`.

## DI
The project uses per-feature DI via `*_injection.dart`.

## Files
See lib/fake/made_up.dart for the wiring.
''';

http_testing.MockClient _successClient(String responseText) {
  return http_testing.MockClient((_) async {
    return http.Response(
      jsonEncode({
        'content': [
          {'type': 'text', 'text': responseText},
        ],
      }),
      200,
    );
  });
}

void main() {
  group('SkillGenerator × DraftVerifier (hallucination regression)', () {
    test('annotate mode (default) inlines UNVERIFIED markers', () async {
      final gen = SkillGenerator(
        apiKey: 'sk-ant-test',
        httpClient: _successClient(_hallucinatedDraft),
        verifierMode: VerifierMode.annotate,
      );
      final result = await gen.generate(_factsWithEvidence());

      expect(result, contains('UNVERIFIED'));
      expect(result, contains('LoginCubit'));
      expect(result, contains('lib/fake/made_up.dart'));
      // The real AuthBloc reference should NOT be flagged.
      final authBlocLine = result
          .split('\n')
          .firstWhere((l) => l.contains('auth_bloc.dart'), orElse: () => '');
      // AuthBloc only appears inside the evidence-grounded passages;
      // the hallucinated draft doesn't mention it.
      expect(authBlocLine, isEmpty);
    });

    test('strip mode removes offending lines from the draft', () async {
      final gen = SkillGenerator(
        apiKey: 'sk-ant-test',
        httpClient: _successClient(_hallucinatedDraft),
        verifierMode: VerifierMode.strip,
      );
      final result = await gen.generate(_factsWithEvidence());

      expect(result, isNot(contains('LoginCubit')));
      expect(result, isNot(contains('HomeCubit')));
      expect(result, isNot(contains('*_injection.dart')));
      expect(result, isNot(contains('lib/fake/made_up.dart')));
      expect(result, isNot(contains('per-feature DI')));
      // Non-violating lines survive.
      expect(result, contains('# demo_app'));
      expect(result, contains('## Overview'));
    });

    test('fatal mode raises DraftVerificationFailedException', () async {
      final gen = SkillGenerator(
        apiKey: 'sk-ant-test',
        httpClient: _successClient(_hallucinatedDraft),
        verifierMode: VerifierMode.fatal,
      );
      expect(
        () => gen.generate(_factsWithEvidence()),
        throwsA(isA<DraftVerificationFailedException>()),
      );
    });

    test('clean drafts pass through all three modes unchanged', () async {
      const cleanDraft =
          '# demo_app\n\nThe AuthBloc lives at '
          'lib/features/auth/presentation/bloc/auth_bloc.dart.\n'
          'DI is centralized in lib/core/di/injection.dart.\n'
          'Files follow `*_bloc.dart`.\n';

      for (final mode in VerifierMode.values) {
        final gen = SkillGenerator(
          apiKey: 'sk-ant-test',
          httpClient: _successClient(cleanDraft),
          verifierMode: mode,
        );
        final result = await gen.generate(_factsWithEvidence());
        expect(result, contains(cleanDraft), reason: 'mode: ${mode.name}');
        expect(result, isNot(contains('UNVERIFIED')));
      }
    });

    test('no evidence bundle means no verification', () async {
      const factsNoEvidence = ProjectFacts(
        projectName: 'demo_app',
        dependencies: DependencyInfo(),
        structure: StructureInfo(organization: 'feature-first'),
        patterns: PatternInfo(),
        conventions: ConventionInfo(),
        generatedAt: '2026-04-20T00:00:00Z',
        toolVersion: '0.2.0',
      );

      // Even in fatal mode, missing evidence cannot trigger violations.
      final gen = SkillGenerator(
        apiKey: 'sk-ant-test',
        httpClient: _successClient(_hallucinatedDraft),
        verifierMode: VerifierMode.fatal,
      );
      final result = await gen.generate(factsNoEvidence);
      expect(result, contains('LoginCubit'));
    });
  });

  group('SkillGenerator env-var resolution', () {
    test('defaults to annotate when env var is unset', () {
      final gen = SkillGenerator(environment: const {});
      expect(gen.verifierMode, VerifierMode.annotate);
    });

    test('parses strip / fatal / annotate from env var', () {
      expect(
        SkillGenerator(
          environment: const {'FLUTTER_SKILL_VERIFIER_MODE': 'strip'},
        ).verifierMode,
        VerifierMode.strip,
      );
      expect(
        SkillGenerator(
          environment: const {'FLUTTER_SKILL_VERIFIER_MODE': 'fatal'},
        ).verifierMode,
        VerifierMode.fatal,
      );
      expect(
        SkillGenerator(
          environment: const {'FLUTTER_SKILL_VERIFIER_MODE': 'annotate'},
        ).verifierMode,
        VerifierMode.annotate,
      );
    });

    test('env-var parsing is case-insensitive and trim-tolerant', () {
      expect(
        SkillGenerator(
          environment: const {'FLUTTER_SKILL_VERIFIER_MODE': '  FATAL  '},
        ).verifierMode,
        VerifierMode.fatal,
      );
    });

    test('unknown env value falls back to annotate', () {
      expect(
        SkillGenerator(
          environment: const {'FLUTTER_SKILL_VERIFIER_MODE': 'bogus'},
        ).verifierMode,
        VerifierMode.annotate,
      );
    });

    test('explicit verifierMode overrides env var', () {
      final gen = SkillGenerator(
        environment: const {'FLUTTER_SKILL_VERIFIER_MODE': 'fatal'},
        verifierMode: VerifierMode.strip,
      );
      expect(gen.verifierMode, VerifierMode.strip);
    });
  });

  group('DraftVerificationFailedException', () {
    test('toString lists every violation with line + kind', () {
      const ex = DraftVerificationFailedException([
        Violation(
          kind: ViolationKind.unknownClassName,
          claim: 'LoginCubit',
          reason: 'class not declared anywhere under lib/',
          line: 'bad line',
          lineNumber: 7,
        ),
      ]);
      final s = ex.toString();
      expect(s, contains('line 7'));
      expect(s, contains('unknownClassName'));
      expect(s, contains('LoginCubit'));
    });
  });
}
