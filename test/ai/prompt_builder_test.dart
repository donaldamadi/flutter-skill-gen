import 'package:flutter_skill_gen/src/ai/prompt_builder.dart';
import 'package:flutter_skill_gen/src/models/convention_info.dart';
import 'package:flutter_skill_gen/src/models/dependency_info.dart';
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
  });
}
