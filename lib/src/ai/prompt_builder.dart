import 'dart:convert';

import '../models/domain_facts.dart';
import '../models/project_facts.dart';

/// Builds system and user prompts for the Claude API from
/// [ProjectFacts] or [DomainFacts], so Claude can generate
/// high-quality SKILL.md files.
class PromptBuilder {
  const PromptBuilder._();

  /// The system prompt that instructs Claude on the SKILL.md format.
  static const systemPrompt =
      'You are an expert Flutter/Dart architect. Your job is to '
      'produce a SKILL.md file that gives an AI coding assistant '
      'complete project literacy from the first prompt.\n'
      '\n'
      'The user will provide a JSON object describing a Flutter '
      "project's dependencies, folder structure, architectural "
      'patterns, code conventions, testing setup, and complexity '
      'metrics.\n'
      '\n'
      'Generate a SKILL.md with these sections:\n'
      '\n'
      '## Project Overview\n'
      'One paragraph: what the project is, its tech stack summary.\n'
      '\n'
      '## Architecture\n'
      'Describe the architecture pattern, how layers are organized, '
      'and where domain boundaries sit. Be specific to THIS '
      'project — not generic Clean Architecture boilerplate.\n'
      '\n'
      '## State Management\n'
      'How state is managed, which pattern/library, how '
      'events/actions flow. Include naming conventions for BLoC '
      'events/states or Riverpod providers if detected.\n'
      '\n'
      '## Routing\n'
      'Which router is used, how routes are organized, any guards '
      'or redirect patterns.\n'
      '\n'
      '## Dependency Injection\n'
      'How DI is set up, which container, how to register new '
      'dependencies.\n'
      '\n'
      '## Data Layer\n'
      'API client, networking approach, local storage, model '
      'serialization. Include code generation commands if '
      'build_runner is used.\n'
      '\n'
      '## Code Conventions\n'
      'File naming, class naming, import style, barrel files. Show '
      "concrete examples from the project's own patterns.\n"
      '\n'
      '## Do / Don\'t Rules\n'
      'Bullet list of project-specific rules an AI assistant MUST '
      'follow when generating code for this project. Derive these '
      'from the detected patterns — e.g. "DO use freezed for all '
      'data classes", "DON\'T use relative imports", "DO put use '
      'cases in domain/usecases/", etc.\n'
      '\n'
      '## Testing\n'
      'How tests are structured, which mocking library, how to '
      'run tests.\n'
      '\n'
      '## Code Generation\n'
      'If the project uses build_runner, freezed, '
      'json_serializable, etc., document the exact commands and '
      'what triggers regeneration.\n'
      '\n'
      'Rules for your output:\n'
      '- Write in second person ("you should", "use X for Y")\n'
      '- Be specific and actionable — reference actual folder '
      'paths, package names, and patterns from the JSON\n'
      '- Do NOT repeat the JSON back — synthesize it into human '
      'prose\n'
      '- Do NOT include generic Flutter advice — only '
      'project-specific rules\n'
      '- Keep it under 2000 words\n'
      '- Output raw markdown only — no wrapping code fences\n'
      '- Do NOT include YAML frontmatter — it is added automatically';

  /// System prompt for the **core** skill file in split mode.
  ///
  /// Instructs Claude to focus on project-wide patterns and omit
  /// feature-specific details, which are covered by domain skills.
  static const coreSystemPrompt =
      'You are an expert Flutter/Dart architect. Your job is to '
      'produce a CORE SKILL.md file that gives an AI coding assistant '
      'project-wide literacy.\n'
      '\n'
      'This project is large enough that domain-specific skills are '
      'generated separately for individual features. This core skill '
      'should cover ONLY project-wide concerns.\n'
      '\n'
      'The user will provide a JSON object describing the project.\n'
      '\n'
      'Generate a SKILL.md with these sections:\n'
      '\n'
      '## Project Overview\n'
      'One paragraph: what the project is, its tech stack summary, '
      'monorepo structure if applicable.\n'
      '\n'
      '## Architecture\n'
      'The architecture pattern, how layers are organized, and where '
      'domain boundaries sit. Be specific to THIS project.\n'
      '\n'
      '## State Management\n'
      'Which pattern/library, how events/actions flow. Include naming '
      'conventions for BLoC events/states or providers if detected.\n'
      '\n'
      '## Routing\n'
      'Which router, how routes are organized, guards or redirects.\n'
      '\n'
      '## Dependency Injection\n'
      'DI container, how to register new dependencies.\n'
      '\n'
      '## Data Layer\n'
      'API client, model serialization, error handling pattern. '
      'Include code generation commands if build_runner is used.\n'
      '\n'
      '## Code Conventions\n'
      'File naming, class naming, import style, barrel files.\n'
      '\n'
      '## Do / Don\'t Rules\n'
      'Project-specific rules an AI assistant MUST follow.\n'
      '\n'
      'Rules for your output:\n'
      '- Write in second person ("you should", "use X for Y")\n'
      '- Be specific — reference actual folder paths and packages\n'
      '- Do NOT include feature-specific details (individual screens, '
      'individual cubits/blocs, individual entities)\n'
      '- Do NOT repeat the JSON back — synthesize it into prose\n'
      '- Keep it under 1500 words\n'
      '- Output raw markdown only — no wrapping code fences\n'
      '- Do NOT include YAML frontmatter — it is added automatically';

  /// System prompt for **domain-specific** skill files.
  static const domainSystemPrompt =
      'You are an expert Flutter/Dart architect. Your job is to '
      'produce a DOMAIN SKILL.md file for a specific feature within '
      'a Flutter project.\n'
      '\n'
      'The user will provide:\n'
      '1. A summary of the project-wide patterns (architecture, state '
      'management, DI, etc.)\n'
      '2. Domain-specific facts: file list, code samples, state '
      'classes, and entities for this feature.\n'
      '\n'
      'Generate a focused SKILL.md with these sections:\n'
      '\n'
      '## Overview\n'
      'What this feature does and its role in the app.\n'
      '\n'
      '## Data Flow\n'
      'How data moves through this feature: API → repository → '
      'use case → state management → UI. Name the actual classes.\n'
      '\n'
      '## State Management\n'
      'List the BLoCs/Cubits/Notifiers in this feature, their '
      'states, and key events/methods. Be specific with class names.\n'
      '\n'
      '## Entities & Models\n'
      'Key data classes in this feature, their purpose, and how '
      'they map between layers (DTO → domain entity).\n'
      '\n'
      '## Screens & Navigation\n'
      'Key screens/pages in this feature and how they connect to '
      'the app\'s routing.\n'
      '\n'
      '## Do / Don\'t Rules\n'
      'Feature-specific rules for code generation in this domain.\n'
      '\n'
      'Rules for your output:\n'
      '- Write in second person ("you should")\n'
      '- Reference actual class names, file paths, and patterns\n'
      '- Do NOT explain project-wide architecture — the core skill '
      'covers that\n'
      '- Keep it under 800 words\n'
      '- Output raw markdown only — no wrapping code fences\n'
      '- Do NOT include YAML frontmatter — it is added automatically';

  /// Builds the user message containing the project facts as JSON.
  static String buildUserMessage(ProjectFacts facts) {
    final json = const JsonEncoder.withIndent('  ').convert(facts.toJson());
    return 'Here are the analyzed facts for the Flutter project '
        '"${facts.projectName}":\n\n```json\n$json\n```\n\n'
        'Generate the SKILL.md content for this project.';
  }

  /// Builds the user message for the **core** skill in split mode.
  ///
  /// Same as [buildUserMessage] but with an explicit instruction
  /// to focus on project-wide concerns.
  static String buildCoreMessage(ProjectFacts facts) {
    final json = const JsonEncoder.withIndent('  ').convert(facts.toJson());
    return 'Here are the analyzed facts for the Flutter project '
        '"${facts.projectName}":\n\n```json\n$json\n```\n\n'
        'Generate the CORE SKILL.md for this project. Focus on '
        'project-wide architecture, conventions, and patterns. '
        'Domain-specific details are covered in separate skill files.';
  }

  /// Builds the user message for a **domain-specific** skill file.
  static String buildDomainMessage(
    DomainFacts domainFacts,
    ProjectFacts projectFacts,
  ) {
    final domainJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(domainFacts.toJson());

    // Provide a compact summary of project-wide context.
    final projectSummary = StringBuffer()
      ..writeln('Project: ${projectFacts.projectName}')
      ..writeln(
        'Architecture: ${projectFacts.patterns.architecture ?? "unspecified"}',
      )
      ..writeln(
        'State management: '
        '${projectFacts.patterns.stateManagement ?? "unspecified"}',
      )
      ..writeln('DI: ${projectFacts.patterns.di ?? "unspecified"}')
      ..writeln(
        'API client: '
        '${projectFacts.patterns.apiClient ?? "unspecified"}',
      )
      ..writeln(
        'Error handling: '
        '${projectFacts.patterns.errorHandling ?? "unspecified"}',
      )
      ..writeln(
        'Model approach: '
        '${projectFacts.patterns.modelApproach ?? "unspecified"}',
      )
      ..writeln('Organization: ${projectFacts.structure.organization}');

    return 'Project-wide context:\n'
        '```\n$projectSummary```\n\n'
        'Domain facts for "${domainFacts.domainName}":\n\n'
        '```json\n$domainJson\n```\n\n'
        'Generate the domain SKILL.md for the '
        '"${domainFacts.domainName}" feature.';
  }
}
