import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../ai/claude_client.dart';
import '../ai/prompt_builder.dart';
import '../models/domain_facts.dart';
import '../models/evidence_bundle.dart';
import '../models/project_facts.dart';
import '../utils/logger.dart';
import '../utils/skill_name.dart';
import '../verifier/draft_verifier.dart';
import 'ascii_diagrams.dart';
import 'gotchas_library.dart';
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
    this.model = 'claude-sonnet-4-6',
    Logger? logger,
    http.Client? httpClient,
    VerifierMode? verifierMode,
    Map<String, String>? environment,
  }) : logger = logger ?? const Logger(),
       _httpClient = httpClient,
       verifierMode =
           verifierMode ??
           _resolveVerifierMode(environment ?? Platform.environment);

  /// Claude API key. `null` means template-only mode.
  final String? apiKey;

  /// Claude model ID.
  final String model;

  /// Logger for diagnostic output.
  final Logger logger;

  /// Optional HTTP client for testing.
  final http.Client? _httpClient;

  /// Mode used by [DraftVerifier] to reconcile AI drafts with the
  /// grounded evidence bundle. Defaults to the value of the
  /// `FLUTTER_SKILL_VERIFIER_MODE` env var (`annotate`, `strip`, or
  /// `fatal`), or [VerifierMode.annotate] if the var is unset.
  final VerifierMode verifierMode;

  /// Name of the environment variable that overrides [verifierMode].
  static const verifierModeEnvVar = 'FLUTTER_SKILL_VERIFIER_MODE';

  static VerifierMode _resolveVerifierMode(Map<String, String> env) {
    final raw = env[verifierModeEnvVar]?.trim().toLowerCase();
    return switch (raw) {
      'strip' => VerifierMode.strip,
      'fatal' => VerifierMode.fatal,
      _ => VerifierMode.annotate,
    };
  }

  /// Whether AI-powered generation is available.
  bool get hasAi => apiKey != null && apiKey!.isNotEmpty;

  /// Generates SKILL.md content from [facts] with Agent Skills
  /// spec-compliant YAML frontmatter.
  ///
  /// Returns the generated markdown string.
  Future<String> generate(ProjectFacts facts) async {
    final aiContent = await _generateContent(facts);
    final body = _spliceDeterministicSections(
      aiContent,
      diagram: AsciiDiagrams.forProject(facts),
      gotchas: GotchasLibrary.renderSection(GotchasLibrary.forProject(facts)),
    );
    final name = SkillName.normalize(facts.projectName);
    final description = _buildDescription(facts);
    final paths = _pathsForCore(facts);
    return '${SkillName.frontmatter(name: name, description: description, paths: paths)}'
        '$body';
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
  /// Returns a map of `scopeKey → content` where each key is the
  /// unprefixed skill scope (`core`, `auth`, `home`, …) and each value
  /// includes Agent-Skills-compliant YAML frontmatter whose `name`
  /// field is prefixed with the project name. Using the unprefixed
  /// scope as the map key lets multi-file writers produce clean output
  /// filenames (`SKILL_auth.md`) that match what `ManifestGenerator`
  /// promises.
  Future<Map<String, String>> generateAll(
    SkillPlan plan,
    ProjectFacts facts,
  ) async {
    final results = <String, String>{};

    for (final spec in plan.specs) {
      String content;
      String frontmatterName;
      String description;
      List<String> paths;

      if (spec.isDomain && spec.domainFacts != null) {
        frontmatterName = SkillName.withSuffix(
          facts.projectName,
          spec.skillName,
        );
        description = _buildDomainDescription(spec.domainFacts!, facts);
        final featureEvidence = _featureEvidenceFor(spec.skillName, facts);
        paths = _pathsForDomain(spec.domainFacts!, facts, featureEvidence);
        logger.info('Generating domain skill: ${spec.skillName}...');
        final aiContent = await generateDomain(spec.domainFacts!, facts);
        content = _spliceDeterministicSections(
          aiContent,
          diagram: featureEvidence == null
              ? ''
              : AsciiDiagrams.forFeature(featureEvidence, facts),
          gotchas: featureEvidence == null
              ? ''
              : GotchasLibrary.renderSection(
                  GotchasLibrary.forFeature(featureEvidence, facts),
                ),
        );
      } else {
        frontmatterName = SkillName.withSuffix(facts.projectName, 'core');
        description = _buildCoreDescription(facts);
        paths = _pathsForCore(facts, isSplit: plan.isSplit);
        String aiContent;
        if (plan.isSplit) {
          logger.info('Generating core skill...');
          aiContent = await _generateCoreWithAi(facts);
        } else {
          aiContent = await _generateContent(facts);
        }
        content = _spliceDeterministicSections(
          aiContent,
          diagram: AsciiDiagrams.forProject(facts),
          gotchas: GotchasLibrary.renderSection(
            GotchasLibrary.forProject(facts),
          ),
        );
      }

      final frontmatter = SkillName.frontmatter(
        name: frontmatterName,
        description: description,
        paths: paths,
      );
      results[spec.skillName] = '$frontmatter$content';
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
      return _verifyDraft(content, facts, label: 'core');
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
      return _verifyDraft(
        content,
        projectFacts,
        label: 'domain/${domainFacts.domainName}',
      );
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
      return _verifyDraft(content, facts);
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
  // Draft verification
  // -------------------------------------------------------------------

  /// Runs the [DraftVerifier] against [draft] using [verifierMode].
  ///
  /// Returns the (possibly transformed) content. Throws
  /// [DraftVerificationFailedException] when the mode is `fatal` and
  /// violations were found. No-ops when `facts.evidence` is null —
  /// without a ground-truth bundle there is nothing to verify.
  String _verifyDraft(String draft, ProjectFacts facts, {String? label}) {
    final evidence = facts.evidence;
    if (evidence == null) return draft;

    final verifier = DraftVerifier(evidence: evidence, mode: verifierMode);
    final result = verifier.verify(draft);
    if (result.violations.isEmpty) return result.output;

    final prefix = label == null ? 'Verifier' : 'Verifier ($label)';
    final byKind = <ViolationKind, int>{};
    for (final v in result.violations) {
      byKind[v.kind] = (byKind[v.kind] ?? 0) + 1;
    }
    final summary = byKind.entries
        .map((e) => '${e.value} ${e.key.name}')
        .join(', ');
    logger.warn(
      '$prefix: ${result.violations.length} claim(s) unsupported '
      'by evidence ($summary). Mode: ${verifierMode.name}.',
    );

    if (verifierMode == VerifierMode.fatal) {
      throw DraftVerificationFailedException(result.violations);
    }
    return result.output;
  }

  // -------------------------------------------------------------------
  // Frontmatter description builders
  //
  // The `description:` field is a loading trigger, not a human
  // summary — Claude Code reads it to decide *when* to surface the
  // skill. We phrase each one as a short "load when …" clause so the
  // model has something concrete to match against the current task.
  // -------------------------------------------------------------------

  String _buildDescription(ProjectFacts facts) {
    final stack = _stackPhrase(facts);
    return 'Load when working in the $stack app '
        '"${facts.projectName}" — architecture, conventions, and '
        'project-specific rules.';
  }

  String _buildCoreDescription(ProjectFacts facts) {
    final stack = _stackPhrase(facts);
    return 'Load for any cross-cutting task in the $stack app '
        '"${facts.projectName}" — architecture, DI, routing, '
        'codegen, or shared conventions. Feature-specific work '
        'loads the matching feature skill.';
  }

  String _buildDomainDescription(DomainFacts domain, ProjectFacts facts) {
    final name = _humanizeScope(domain.domainName);
    final layers = domain.layers.isEmpty ? '' : ' (${domain.layers.join('/')})';
    return 'Load when editing the "$name" feature$layers '
        'in ${facts.projectName} — feature-specific classes, data '
        'flow, and gotchas.';
  }

  String _stackPhrase(ProjectFacts facts) {
    final parts = <String>[];
    if (facts.patterns.architecture != null) {
      parts.add(facts.patterns.architecture!.replaceAll('_', ' '));
    }
    if (facts.patterns.stateManagement != null) {
      parts.add('${facts.patterns.stateManagement}');
    }
    if (parts.isEmpty) return 'Flutter';
    return 'Flutter + ${parts.join(' + ')}';
  }

  String _humanizeScope(String scope) {
    final normalized = scope.replaceAll('_', ' ').replaceAll('-', ' ');
    if (normalized.isEmpty) return scope;
    return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }

  // -------------------------------------------------------------------
  // Path computation (Claude Code `paths:` frontmatter)
  //
  // Skills with a `paths:` block are lazy-loaded only when a matching
  // file is touched. Scoping the core skill to cross-cutting paths
  // and each feature skill to its own directory keeps context budgets
  // low without having to pre-read every skill.
  // -------------------------------------------------------------------

  List<String> _pathsForCore(ProjectFacts facts, {bool isSplit = false}) {
    final paths = <String>{'pubspec.yaml', 'lib/main.dart'};
    const sharedRoots = ['core', 'shared', 'common', 'config', 'app'];
    for (final dir in facts.structure.topLevelDirs) {
      if (sharedRoots.contains(dir)) {
        paths.add('lib/$dir/**/*.dart');
      }
    }
    // When not split, the core skill covers everything.
    if (!isSplit) {
      paths.add('lib/**/*.dart');
    }
    return paths.toList();
  }

  List<String> _pathsForDomain(
    DomainFacts domain,
    ProjectFacts facts,
    FeatureEvidence? featureEvidence,
  ) {
    final featurePath = featureEvidence?.path ?? _guessFeaturePath(domain);
    if (featurePath.isEmpty) return const [];
    return ['$featurePath/**/*.dart'];
  }

  String _guessFeaturePath(DomainFacts domain) {
    if (domain.files.isEmpty) return '';
    // The domain's first file starts with its resolved root path; the
    // evidence's `feature.path` is more reliable but falls back to
    // this when the bundle is absent.
    final first = domain.files.first.replaceAll(r'\\', '/');
    // Trim off the trailing file to get the directory root. This is
    // coarse but only runs when FeatureEvidence is missing.
    final slash = first.lastIndexOf('/');
    return slash > 0 ? first.substring(0, slash) : '';
  }

  FeatureEvidence? _featureEvidenceFor(String scope, ProjectFacts facts) {
    final bundle = facts.evidence;
    if (bundle == null) return null;
    for (final f in bundle.features) {
      if (f.name == scope) return f;
    }
    return null;
  }

  // -------------------------------------------------------------------
  // Deterministic section splicing
  //
  // Gotchas and data-flow diagrams are generated from trusted sources
  // (the GotchasLibrary and AsciiDiagrams modules), never from AI
  // output, so they skip the verifier and get appended to whatever
  // the model produced. This keeps the high-signal content in every
  // skill even when the AI path fails or the user runs template-only.
  // -------------------------------------------------------------------

  String _spliceDeterministicSections(
    String aiContent, {
    required String diagram,
    required String gotchas,
  }) {
    final body = aiContent.trimRight();
    final buf = StringBuffer()..write(body);
    if (diagram.isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..write(diagram);
    }
    if (gotchas.isNotEmpty) {
      buf
        ..writeln()
        ..write(gotchas);
    }
    return buf.toString();
  }
}
