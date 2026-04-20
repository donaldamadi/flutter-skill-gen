import 'package:flutter_skill_gen/src/ai/prompt_builder.dart';
import 'package:flutter_skill_gen/src/models/convention_info.dart';
import 'package:flutter_skill_gen/src/models/dependency_info.dart';
import 'package:flutter_skill_gen/src/models/domain_facts.dart';
import 'package:flutter_skill_gen/src/models/evidence_bundle.dart';
import 'package:flutter_skill_gen/src/models/pattern_info.dart';
import 'package:flutter_skill_gen/src/models/project_facts.dart';
import 'package:flutter_skill_gen/src/models/structure_info.dart';
import 'package:test/test.dart';

void main() {
  group('PromptBuilder', () {
    group('systemPrompt', () {
      test('is non-empty', () {
        expect(PromptBuilder.systemPrompt, isNotEmpty);
      });

      test('mentions SKILL.md', () {
        expect(PromptBuilder.systemPrompt, contains('SKILL.md'));
      });

      test('contains required section headers', () {
        const prompt = PromptBuilder.systemPrompt;
        expect(prompt, contains('## Project Overview'));
        expect(prompt, contains('## Architecture'));
        expect(prompt, contains('## State Management'));
        expect(prompt, contains('## Routing'));
        expect(prompt, contains('## Dependency Injection'));
        expect(prompt, contains('## Data Layer'));
        expect(prompt, contains('## Code Conventions'));
        expect(prompt, contains("## Do / Don't Rules"));
        expect(prompt, contains('## Testing'));
        expect(prompt, contains('## Code Generation'));
      });

      test('instructs output format', () {
        const prompt = PromptBuilder.systemPrompt;
        expect(prompt, contains('raw markdown'));
        expect(prompt, contains('under 2000 words'));
      });
    });

    group('buildUserMessage', () {
      late ProjectFacts facts;

      setUp(() {
        facts = const ProjectFacts(
          projectName: 'test_app',
          projectDescription: 'A test application',
          flutterSdk: '>=3.24.0',
          dartSdk: '^3.5.0',
          dependencies: DependencyInfo(
            stateManagement: ['flutter_bloc', 'bloc'],
            routing: ['go_router'],
            di: ['get_it'],
            networking: ['dio'],
          ),
          structure: StructureInfo(
            organization: 'feature-first',
            topLevelDirs: ['core', 'features'],
            featureDirs: ['auth', 'home'],
          ),
          patterns: PatternInfo(
            architecture: 'clean_architecture',
            stateManagement: 'bloc',
            routing: 'go_router',
            di: 'get_it_injectable',
          ),
          conventions: ConventionInfo(),
          generatedAt: '2026-04-16T12:00:00Z',
          toolVersion: '0.1.0',
        );
      });

      test('contains the project name', () {
        final message = PromptBuilder.buildUserMessage(facts);
        expect(message, contains('test_app'));
      });

      test('contains valid JSON block', () {
        final message = PromptBuilder.buildUserMessage(facts);
        expect(message, contains('```json'));
        expect(message, contains('```'));
      });

      test('contains project facts as JSON', () {
        final message = PromptBuilder.buildUserMessage(facts);
        expect(message, contains('"project_name": "test_app"'));
        expect(message, contains('"architecture": "clean_architecture"'));
        expect(message, contains('"state_management": "bloc"'));
      });

      test('ends with generation instruction', () {
        final message = PromptBuilder.buildUserMessage(facts);
        expect(message, contains('Generate the SKILL.md content'));
      });

      test('includes dependency info in JSON', () {
        final message = PromptBuilder.buildUserMessage(facts);
        expect(message, contains('flutter_bloc'));
        expect(message, contains('go_router'));
        expect(message, contains('get_it'));
        expect(message, contains('dio'));
      });
    });

    group('grounding rules', () {
      test('groundingRules constant calls out every evidence field', () {
        const rules = PromptBuilder.groundingRules;
        expect(rules, contains('evidence.file_manifest.all_file_paths'));
        expect(rules, contains('evidence.file_manifest.all_class_names'));
        expect(rules, contains('evidence.known_file_patterns'));
        expect(rules, contains('evidence.di.per_feature'));
        expect(rules, contains('evidence.di.registration_files'));
        expect(rules, contains('layers_absent'));
        expect(rules, contains('widget_usage'));
      });

      test('systemPrompt includes the grounding rules verbatim', () {
        expect(
          PromptBuilder.systemPrompt,
          contains(PromptBuilder.groundingRules),
        );
      });

      test('coreSystemPrompt includes the grounding rules verbatim', () {
        expect(
          PromptBuilder.coreSystemPrompt,
          contains(PromptBuilder.groundingRules),
        );
      });

      test('domainSystemPrompt includes the grounding rules verbatim', () {
        expect(
          PromptBuilder.domainSystemPrompt,
          contains(PromptBuilder.groundingRules),
        );
      });

      test('output rules remain in place ahead of grounding', () {
        const prompt = PromptBuilder.systemPrompt;
        final outputRulesIdx = prompt.indexOf('Rules for your output');
        final groundingIdx = prompt.indexOf('CRITICAL — grounding rules');
        expect(outputRulesIdx, greaterThanOrEqualTo(0));
        expect(groundingIdx, greaterThan(outputRulesIdx));
      });
    });

    group('buildDomainMessage with evidence', () {
      late ProjectFacts facts;

      setUp(() {
        facts = const ProjectFacts(
          projectName: 'test_app',
          dependencies: DependencyInfo(),
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
            projectName: 'test_app',
            features: [
              FeatureEvidence(
                name: 'auth',
                path: 'lib/features/auth',
                layersPresent: ['data', 'domain', 'presentation'],
                layersAbsent: [],
                fileCount: 4,
                stateClasses: [
                  ClassReference(
                    name: 'AuthBloc',
                    file: 'lib/features/auth/presentation/bloc/auth_bloc.dart',
                  ),
                ],
                widgetUsage: {'BlocBuilder': 2},
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
      });

      test('includes a grounded evidence slice with the feature', () {
        final msg = PromptBuilder.buildDomainMessage(
          const DomainFacts(domainName: 'auth'),
          facts,
        );
        expect(msg, contains('Evidence (ground truth'));
        expect(msg, contains('"feature_evidence"'));
        expect(msg, contains('"AuthBloc"'));
        expect(msg, contains('lib/core/di/injection.dart'));
        expect(msg, contains('*_bloc.dart'));
      });

      test('omits feature_evidence when the domain is unknown', () {
        final msg = PromptBuilder.buildDomainMessage(
          const DomainFacts(domainName: 'settings'),
          facts,
        );
        expect(msg, contains('Evidence (ground truth'));
        expect(msg, isNot(contains('"feature_evidence"')));
        // Project-wide blocks are still present.
        expect(msg, contains('"file_manifest"'));
        expect(msg, contains('"di"'));
      });

      test('still works and emits no evidence block when evidence is null', () {
        final nudged = ProjectFacts(
          projectName: facts.projectName,
          dependencies: facts.dependencies,
          structure: facts.structure,
          patterns: facts.patterns,
          conventions: facts.conventions,
          generatedAt: facts.generatedAt,
          toolVersion: facts.toolVersion,
        );
        final msg = PromptBuilder.buildDomainMessage(
          const DomainFacts(domainName: 'auth'),
          nudged,
        );
        expect(msg, isNot(contains('Evidence (ground truth')));
        expect(msg, contains('Generate the domain SKILL.md'));
      });
    });

    group('golden — full system+user prompt shape', () {
      // Locks the prompt shape so any intentional rewrite requires an
      // explicit test update. We assert on ordered anchors rather than
      // a single massive string to keep the test tractable.
      test('systemPrompt section ordering is stable', () {
        const prompt = PromptBuilder.systemPrompt;
        final anchors = <String>[
          '## Project Overview',
          '## Architecture',
          '## State Management',
          '## Routing',
          '## Dependency Injection',
          '## Data Layer',
          '## Code Conventions',
          "## Do / Don't Rules",
          '## Testing',
          '## Code Generation',
          'Rules for your output',
          'CRITICAL — grounding rules',
          'evidence.file_manifest.all_file_paths',
          'evidence.di.per_feature',
        ];
        var last = -1;
        for (final a in anchors) {
          final idx = prompt.indexOf(a);
          expect(
            idx,
            greaterThan(last),
            reason: 'anchor "$a" out of order (found at $idx, prev $last)',
          );
          last = idx;
        }
      });

      test('coreSystemPrompt ends with grounding rules', () {
        expect(
          PromptBuilder.coreSystemPrompt.trimRight(),
          endsWith(PromptBuilder.groundingRules.trimRight()),
        );
      });

      test('domainSystemPrompt ends with grounding rules', () {
        expect(
          PromptBuilder.domainSystemPrompt.trimRight(),
          endsWith(PromptBuilder.groundingRules.trimRight()),
        );
      });
    });
  });
}
