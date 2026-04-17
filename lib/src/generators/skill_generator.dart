import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../ai/claude_client.dart';
import '../ai/prompt_builder.dart';
import '../models/domain_facts.dart';
import '../models/project_facts.dart';
import '../utils/logger.dart';
import '../utils/skill_name.dart';
import 'split_planner.dart';
import 'template_generator.dart';

/// Generates a `SKILL.md` file from [ProjectFacts].
///
/// Uses the Claude API when an API key is available, falling back to
/// template-based generation otherwise.
class SkillGenerator {
  /// Creates a [SkillGenerator].
  ///
  /// Pass [apiKey] and optionally [model] to enable AI-powered
  /// generation. When [apiKey] is `null`, the template fallback
  /// is used. An optional [httpClient] can be injected for testing.
  SkillGenerator({
    this.apiKey,
    this.model = 'claude-sonnet-4-20250514',
    Logger? logger,
    http.Client? httpClient,
  }) : logger = logger ?? const Logger(),
       _httpClient = httpClient;

  /// Claude API key. `null` means template-only mode.
  final String? apiKey;

  /// Claude model ID.
  final String model;

  /// Logger for diagnostic output.
  final Logger logger;

  /// Optional HTTP client for testing.
  final http.Client? _httpClient;

  /// Whether AI-powered generation is available.
  bool get hasAi => apiKey != null && apiKey!.isNotEmpty;

  /// Generates SKILL.md content from [facts] with Agent Skills
  /// spec-compliant YAML frontmatter.
  ///
  /// Returns the generated markdown string.
  Future<String> generate(ProjectFacts facts) async {
    final content = await _generateContent(facts);
    final name = SkillName.normalize(facts.projectName);
    final description = _buildDescription(facts);
    return '${SkillName.frontmatter(name: name, description: description)}'
        '$content';
  }

  /// Generates raw skill content without frontmatter.
  Future<String> _generateContent(ProjectFacts facts) async {
    if (hasAi) {
      return _generateWithAi(facts);
    }
    logger.info(
      'No API key configured — using template-based '
      'generation.',
    );
    return TemplateGenerator.generate(facts);
  }

  /// Generates SKILL.md content and writes it to [outputDir].
  ///
  /// Returns the absolute path of the written file.
  Future<String> generateAndWrite(
    ProjectFacts facts, {
    required String outputDir,
  }) async {
    final content = await generate(facts);
    final outputPath = p.join(outputDir, 'SKILL.md');
    final file = File(outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    return outputPath;
  }

  /// Generates a domain-specific SKILL.md for [domainFacts].
  ///
  /// [projectFacts] provides project-wide context for the prompt.
  Future<String> generateDomain(
    DomainFacts domainFacts,
    ProjectFacts projectFacts,
  ) async {
    if (hasAi) {
      return _generateDomainWithAi(domainFacts, projectFacts);
    }
    return TemplateGenerator.generateDomain(domainFacts, projectFacts);
  }

  /// Generates all skill files described in [plan].
  ///
  /// Returns a map of `skillName → content` where each skill name
  /// is Agent Skills spec-compliant and each value includes YAML
  /// frontmatter.
  Future<Map<String, String>> generateAll(
    SkillPlan plan,
    ProjectFacts facts,
  ) async {
    final results = <String, String>{};

    for (final spec in plan.specs) {
      String content;
      String skillName;
      String description;

      if (spec.isDomain && spec.domainFacts != null) {
        skillName = SkillName.withSuffix(
          facts.projectName,
          spec.skillName,
        );
        description = _buildDomainDescription(
          spec.domainFacts!,
          facts,
        );
        logger.info('Generating domain skill: ${spec.skillName}...');
        content = await generateDomain(spec.domainFacts!, facts);
      } else {
        skillName = SkillName.withSuffix(
          facts.projectName,
          'core',
        );
        description = _buildCoreDescription(facts);
        if (plan.isSplit) {
          logger.info('Generating core skill...');
          content = await _generateCoreWithAi(facts);
        } else {
          content = await _generateContent(facts);
        }
      }

      final frontmatter = SkillName.frontmatter(
        name: skillName,
        description: description,
      );
      results[skillName] = '$frontmatter$content';
    }

    return results;
  }

  Future<String> _generateCoreWithAi(ProjectFacts facts) async {
    if (!hasAi) {
      return TemplateGenerator.generateCore(facts);
    }

    logger.info('Generating core SKILL.md with Claude ($model)...');

    final client = ClaudeClient(
      apiKey: apiKey!,
      model: model,
      httpClient: _httpClient,
    );

    try {
      final content = await client.complete(
        systemPrompt: PromptBuilder.coreSystemPrompt,
        userMessage: PromptBuilder.buildCoreMessage(facts),
      );
      logger.success('Core skill generation complete.');
      return content;
    } on ClaudeApiException catch (e) {
      logger.warn(
        'AI generation failed: $e\n'
        'Falling back to template-based generation.',
      );
      return TemplateGenerator.generateCore(facts);
    } finally {
      client.close();
    }
  }

  Future<String> _generateDomainWithAi(
    DomainFacts domainFacts,
    ProjectFacts projectFacts,
  ) async {
    logger.info(
      'Generating ${domainFacts.domainName} SKILL.md with '
      'Claude ($model)...',
    );

    final client = ClaudeClient(
      apiKey: apiKey!,
      model: model,
      httpClient: _httpClient,
    );

    try {
      final content = await client.complete(
        systemPrompt: PromptBuilder.domainSystemPrompt,
        userMessage: PromptBuilder.buildDomainMessage(
          domainFacts,
          projectFacts,
        ),
      );
      logger.success('${domainFacts.domainName} skill generation complete.');
      return content;
    } on ClaudeApiException catch (e) {
      logger.warn(
        'AI generation for ${domainFacts.domainName} failed: '
        '$e\nFalling back to template-based generation.',
      );
      return TemplateGenerator.generateDomain(domainFacts, projectFacts);
    } finally {
      client.close();
    }
  }

  Future<String> _generateWithAi(ProjectFacts facts) async {
    logger.info('Generating SKILL.md with Claude ($model)...');

    final client = ClaudeClient(
      apiKey: apiKey!,
      model: model,
      httpClient: _httpClient,
    );

    try {
      final content = await client.complete(
        systemPrompt: PromptBuilder.systemPrompt,
        userMessage: PromptBuilder.buildUserMessage(facts),
      );
      logger.success('AI generation complete.');
      return content;
    } on ClaudeApiException catch (e) {
      logger.warn(
        'AI generation failed: $e\n'
        'Falling back to template-based generation.',
      );
      return TemplateGenerator.generate(facts);
    } finally {
      client.close();
    }
  }

  // -------------------------------------------------------------------
  // Frontmatter description builders
  // -------------------------------------------------------------------

  String _buildDescription(ProjectFacts facts) {
    final parts = <String>[
      'Flutter project context for ${facts.projectName}',
    ];
    if (facts.patterns.architecture != null) {
      parts.add(facts.patterns.architecture!);
    }
    if (facts.patterns.stateManagement != null) {
      parts.add(
        '${facts.patterns.stateManagement} state management',
      );
    }
    return '${parts.join('. ')}.';
  }

  String _buildCoreDescription(ProjectFacts facts) {
    final base = 'Core architecture, conventions, and '
        'dependencies for ${facts.projectName}';
    final parts = <String>[base];
    if (facts.patterns.architecture != null) {
      parts.add(facts.patterns.architecture!);
    }
    return '${parts.join('. ')}.';
  }

  String _buildDomainDescription(
    DomainFacts domain,
    ProjectFacts facts,
  ) {
    final name = domain.domainName
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
    final capitalized =
        '${name[0].toUpperCase()}${name.substring(1)}';
    final base = '$capitalized feature in ${facts.projectName}';
    final parts = <String>[base];
    if (domain.layers.isNotEmpty) {
      parts.add('layers: ${domain.layers.join(', ')}');
    }
    return '${parts.join('. ')}.';
  }
}
