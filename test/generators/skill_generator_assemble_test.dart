import 'package:flutter_skill_gen/src/generators/skill_generator.dart';
import 'package:flutter_skill_gen/src/generators/split_planner.dart';
import 'package:flutter_skill_gen/src/models/convention_info.dart';
import 'package:flutter_skill_gen/src/models/dependency_info.dart';
import 'package:flutter_skill_gen/src/models/domain_facts.dart';
import 'package:flutter_skill_gen/src/models/evidence_bundle.dart';
import 'package:flutter_skill_gen/src/models/pattern_info.dart';
import 'package:flutter_skill_gen/src/models/project_facts.dart';
import 'package:flutter_skill_gen/src/models/structure_info.dart';
import 'package:flutter_skill_gen/src/verifier/draft_verifier.dart';
import 'package:test/test.dart';

/// Project facts carrying an evidence bundle, so the verifier has a
/// ground truth to hold drafts against.
const _facts = ProjectFacts(
  projectName: 'shop_app',
  dependencies: DependencyInfo(stateManagement: ['flutter_bloc']),
  structure: StructureInfo(
    organization: 'feature-first',
    featureDirs: ['auth'],
  ),
  patterns: PatternInfo(
    architecture: 'clean_architecture',
    stateManagement: 'bloc',
  ),
  conventions: ConventionInfo(),
  evidence: EvidenceBundle(
    projectName: 'shop_app',
    features: [
      FeatureEvidence(
        name: 'auth',
        path: 'lib/features/auth',
        layersPresent: ['presentation'],
      ),
    ],
    di: DiEvidence(registrationFiles: ['lib/core/di/injection.dart']),
    knownFilePatterns: ['*_bloc.dart'],
    fileManifest: FileManifest(
      allFilePaths: [
        'lib/core/di/injection.dart',
        'lib/features/auth/presentation/login_page.dart',
      ],
      allClassNames: ['LoginPage'],
    ),
  ),
  generatedAt: '2026-09-11T00:00:00Z',
  toolVersion: '1.1.0',
);

/// A draft asserting a file that is not in the manifest.
const _ungroundedDraft =
    '## Overview\n\n'
    'State lives in `lib/features/auth/presentation/invented.dart`.\n';

const _splitPlan = SkillPlan(
  isSplit: true,
  specs: [
    SkillSpec(skillName: 'core'),
    SkillSpec(
      skillName: 'auth',
      isDomain: true,
      domainFacts: DomainFacts(
        domainName: 'auth',
        files: ['lib/features/auth/presentation/login_page.dart'],
        layers: ['presentation'],
      ),
    ),
  ],
);

void main() {
  group('SkillGenerator.assemble', () {
    test('adds frontmatter an external draft did not carry', () {
      final generator = SkillGenerator(verifierMode: VerifierMode.annotate);

      final result = generator.assemble(_facts, '## Overview\n\nText.');

      expect(result, startsWith('---\n'));
      expect(result, contains('name:'));
      expect(result, contains('description:'));
      expect(result, contains('## Overview'));
    });

    test('splices the deterministic sections onto the draft', () {
      // Gotchas and the data-flow diagram come from trusted
      // generators, so an agent-written draft gets them too.
      final generator = SkillGenerator(verifierMode: VerifierMode.annotate);

      const draft = '## Overview\n\nText.';
      final result = generator.assemble(_facts, draft);

      expect(result.length, greaterThan(draft.length + 100));
    });

    test('annotates a claim the evidence does not support', () {
      final generator = SkillGenerator(verifierMode: VerifierMode.annotate);

      final result = generator.assemble(_facts, _ungroundedDraft);

      expect(result, contains('UNVERIFIED'));
    });

    test('strips an unsupported claim in strip mode', () {
      final generator = SkillGenerator(verifierMode: VerifierMode.strip);

      final result = generator.assemble(_facts, _ungroundedDraft);

      expect(result, isNot(contains('invented.dart')));
    });

    test('throws on an unsupported claim in fatal mode', () {
      // This gate is what makes an agent-written draft safe: the agent
      // can see the whole repo, so only the evidence bundle stops it
      // asserting something plausible but absent.
      final generator = SkillGenerator(verifierMode: VerifierMode.fatal);

      expect(
        () => generator.assemble(_facts, _ungroundedDraft),
        throwsA(isA<DraftVerificationFailedException>()),
      );
    });

    test('leaves a fully grounded draft intact', () {
      final generator = SkillGenerator(verifierMode: VerifierMode.fatal);

      final result = generator.assemble(
        _facts,
        '## Overview\n\n'
        'The `LoginPage` lives in '
        '`lib/features/auth/presentation/login_page.dart`.\n',
      );

      expect(result, contains('login_page.dart'));
      expect(result, isNot(contains('UNVERIFIED')));
    });
  });

  group('SkillGenerator.assembleAll', () {
    test('finishes every scope in the plan', () {
      final generator = SkillGenerator(verifierMode: VerifierMode.annotate);

      final result = generator.assembleAll(_splitPlan, _facts, {
        'core': '## Architecture\n\nFeature-first.',
        'auth': '## Overview\n\nSign-in and sign-up.',
      });

      expect(result.keys, containsAll(['core', 'auth']));
      expect(result['core'], contains('## Architecture'));
      expect(result['auth'], contains('Sign-in and sign-up'));
    });

    test('prefixes each skill name with the project name', () {
      final generator = SkillGenerator(verifierMode: VerifierMode.annotate);

      final result = generator.assembleAll(_splitPlan, _facts, {
        'core': '## Architecture\n\nFeature-first.',
        'auth': '## Overview\n\nSign-in and sign-up.',
      });

      expect(result['auth'], contains('shop-app'));
    });

    test('verifies domain drafts, not just the core draft', () {
      final generator = SkillGenerator(verifierMode: VerifierMode.fatal);

      expect(
        () => generator.assembleAll(_splitPlan, _facts, {
          'core': '## Architecture\n\nFeature-first.',
          'auth': _ungroundedDraft,
        }),
        throwsA(isA<DraftVerificationFailedException>()),
      );
    });

    test('throws when a planned scope has no draft', () {
      final generator = SkillGenerator(verifierMode: VerifierMode.annotate);

      expect(
        () => generator.assembleAll(_splitPlan, _facts, {
          'core': '## Architecture\n\nFeature-first.',
        }),
        throwsA(
          isA<MissingDraftException>().having((e) => e.scope, 'scope', 'auth'),
        ),
      );
    });

    test('throws when a draft is blank', () {
      final generator = SkillGenerator(verifierMode: VerifierMode.annotate);

      expect(
        () => generator.assembleAll(_splitPlan, _facts, {
          'core': '## Architecture\n\nFeature-first.',
          'auth': '   \n ',
        }),
        throwsA(isA<MissingDraftException>()),
      );
    });
  });
}
