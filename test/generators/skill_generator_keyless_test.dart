import 'package:flutter_skill_gen/src/ai/agent_cli_client.dart';
import 'package:flutter_skill_gen/src/ai/llm_client.dart';
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
  group('SkillGenerator.hasAi', () {
    test('is false without a key for a key-requiring provider', () {
      expect(SkillGenerator().hasAi, isFalse);
    });

    test('is true for Claude Code with no key configured', () {
      // The point of the keyless provider: AI generation is available
      // with nothing in the config at all.
      expect(SkillGenerator(provider: LlmProvider.claudeCode).hasAi, isTrue);
    });
  });

  group('SkillGenerator with a keyless provider', () {
    /// A generator pointed at a stand-in executable that always
    /// fails, so the run exercises the real client-construction path
    /// without spawning Claude Code.
    SkillGenerator keyless() => SkillGenerator(
      provider: LlmProvider.claudeCode,
      verifierMode: VerifierMode.annotate,
      environment: {
        AgentCli.claudeCode.executableEnvVar:
            'definitely-not-a-real-binary-xyz',
      },
    );

    test('generates without a key instead of crashing', () async {
      // Regression: the generator used to force-unwrap `apiKey` when
      // building its client, which threw a null-check error the
      // moment a keyless provider reached the AI path.
      final content = await keyless().generate(_facts);

      expect(content, startsWith('---\n'));
      expect(content, contains('shop_app'));
    });

    test('falls back to templates when the CLI cannot be run', () async {
      // A missing binary must degrade exactly like a failing API call.
      final content = await keyless().generate(_facts);

      expect(content, isNotEmpty);
      expect(content, contains('description:'));
    });

    test('generates every scope in split mode without a key', () async {
      final result = await keyless().generateAll(_splitPlan, _facts);

      expect(result.keys, containsAll(['core', 'auth']));
    });
  });
}
