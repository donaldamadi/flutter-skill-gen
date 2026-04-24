import 'dart:convert';

import '../models/domain_facts.dart';
import '../models/evidence_bundle.dart';
import '../models/project_facts.dart';

/// Builds system and user prompts for the Claude API from
/// [ProjectFacts] or [DomainFacts], so Claude can generate
/// high-quality SKILL.md files.
class PromptBuilder {
  const PromptBuilder._();

  /// Anti-hallucination instructions appended to every system prompt.
  ///
  /// Instructs Claude to treat the `evidence` block of the JSON payload
  /// as the sole source of truth for file paths, class names, glob
  /// patterns, and DI wiring. The post-generation `DraftVerifier` uses
  /// the same evidence to reject or annotate unsupported claims, so
  /// any drift here widens the gap between what the model emits and
  /// what the verifier accepts.
  static const groundingRules =
      'CRITICAL — grounding rules (these override any pattern-matching '
      'instinct from prior training):\n'
      '\n'
      'The JSON includes an `evidence` object. Treat it as the ONLY '
      'source of truth for file paths, class names, file-name '
      'patterns, and DI wiring. Do NOT import prior knowledge about '
      '"what a typical Flutter project looks like."\n'
      '\n'
      '- Only mention file paths listed in '
      '`evidence.file_manifest.all_file_paths`. If a path you would '
      'otherwise reference is absent, describe the pattern abstractly '
      '(e.g. "each feature\'s presentation layer") instead of citing '
      'a specific path.\n'
      '- Only reference class names that appear in '
      '`evidence.file_manifest.all_class_names`. Do not invent '
      'example classes like `LoginCubit` or `UserRepositoryImpl` '
      'unless they are listed there.\n'
      '- Only use glob patterns (e.g. `*_bloc.dart`) that appear in '
      '`evidence.known_file_patterns`. If `*_cubit.dart` is not '
      'listed, this project has no cubit files — do not claim it '
      'does.\n'
      '- `evidence.di.per_feature` is authoritative. If false, DI is '
      'centralized — do NOT describe DI as "per-feature" or "each '
      'feature has its own injection file". Instead, cite '
      '`evidence.di.registration_files` for the actual registration '
      'sites.\n'
      '- For each feature, `layers_present` and `layers_absent` are '
      'authoritative. If a feature\'s `layers_absent` contains '
      '"domain", that feature does not have a domain layer — do not '
      'invent one.\n'
      '- `widget_usage` counts are authoritative. If `BlocBuilder` is '
      '0 for a feature, that feature does not use `BlocBuilder` — '
      'describe only widgets with non-zero counts.\n'
      '- When in doubt, prefer the shorter, more cautious phrasing. '
      'A verifier will strip or annotate any claim it cannot find in '
      '`evidence`.\n';

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
      '- Do NOT state the obvious. Skip "this is a Flutter project", '
      '"Dart is used", generic explanations of what BLoC/Riverpod is, '
      'or boilerplate framing about Clean Architecture. Only include '
      'content that would surprise a mid-level Flutter engineer who '
      'just cloned the repo.\n'
      '- Do NOT include a "Gotchas" or "Data Flow" section — those '
      'are generated deterministically and appended after your '
      'output. Writing them yourself creates duplicates.\n'
      '- Hard line budget: under 180 lines total (aim for 120–150). '
      'Claude Code skills degrade past 200 lines. Cut prose before '
      'cutting facts.\n'
      '- Output raw markdown only — no wrapping code fences\n'
      '- Do NOT include YAML frontmatter — it is added automatically\n'
      '\n'
      '$groundingRules';

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
      '- Do NOT state the obvious. Skip "this is a Flutter project", '
      '"Dart is used", generic explanations of BLoC/Riverpod/Clean '
      'Architecture. Keep only content that would surprise an '
      'engineer who just cloned the repo.\n'
      '- Do NOT include a "Gotchas" or "Data Flow" section — those '
      'are generated deterministically and appended after your '
      'output.\n'
      '- Hard line budget: under 150 lines total (aim for 100). '
      'This is the core skill — leaner is better; per-feature '
      'detail lives in the domain skills.\n'
      '- Output raw markdown only — no wrapping code fences\n'
      '- Do NOT include YAML frontmatter — it is added automatically\n'
      '\n'
      '$groundingRules';

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
      '- Do NOT state the obvious. Skip "this is a Flutter feature", '
      'generic BLoC/Riverpod primer content, or Clean Architecture '
      'framing. Keep only what is specific to THIS feature.\n'
      '- Do NOT include a "Gotchas" or "Data Flow" section — those '
      'are generated deterministically and appended after your '
      'output.\n'
      '- Hard line budget: under 120 lines total (aim for 80). '
      'Domain skills are loaded alongside the core skill; each one '
      'over budget hurts every adjacent skill too.\n'
      '- Output raw markdown only — no wrapping code fences\n'
      '- Do NOT include YAML frontmatter — it is added automatically\n'
      '\n'
      '$groundingRules';

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
  ///
  /// Includes (a) a compact project-wide summary, (b) a targeted
  /// `evidence` slice containing only this feature's `FeatureEvidence`
  /// plus the project-wide `file_manifest` and `di` blocks so the
  /// domain prompt has the same grounding surface as the verifier,
  /// and (c) the full [DomainFacts] JSON.
  static String buildDomainMessage(
    DomainFacts domainFacts,
    ProjectFacts projectFacts,
  ) {
    final domainJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(domainFacts.toJson());

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

    final evidenceBlock = _buildDomainEvidenceBlock(
      domainFacts.domainName,
      projectFacts,
    );

    return 'Project-wide context:\n'
        '```\n$projectSummary```\n\n'
        '$evidenceBlock'
        'Domain facts for "${domainFacts.domainName}":\n\n'
        '```json\n$domainJson\n```\n\n'
        'Generate the domain SKILL.md for the '
        '"${domainFacts.domainName}" feature.';
  }

  /// Produces the `Evidence (ground truth):` JSON block for a domain
  /// prompt, or an empty string if the project facts predate the
  /// evidence bundle.
  static String _buildDomainEvidenceBlock(
    String domainName,
    ProjectFacts projectFacts,
  ) {
    final evidence = projectFacts.evidence;
    if (evidence == null) return '';

    FeatureEvidence? feature;
    for (final f in evidence.features) {
      if (f.name == domainName) {
        feature = f;
        break;
      }
    }

    final slice = <String, dynamic>{
      'project_name': evidence.projectName,
      'di': evidence.di.toJson(),
      'known_file_patterns': evidence.knownFilePatterns,
      'file_manifest': evidence.fileManifest.toJson(),
      if (feature != null) 'feature_evidence': feature.toJson(),
    };
    final sliceJson = const JsonEncoder.withIndent('  ').convert(slice);
    return 'Evidence (ground truth — only reference files/classes '
        'listed here):\n```json\n$sliceJson\n```\n\n';
  }
}
