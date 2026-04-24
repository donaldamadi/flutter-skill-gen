import '../analyzers/domain_analyzer.dart';
import '../models/domain_facts.dart';
import '../models/project_facts.dart';

/// Describes a single skill file to generate.
class SkillSpec {
  /// Creates a [SkillSpec].
  const SkillSpec({
    required this.skillName,
    this.isDomain = false,
    this.domainFacts,
  });

  /// Skill name: "core" for the project-wide skill, or a domain name
  /// (e.g. "auth", "home") for domain-specific skills.
  final String skillName;

  /// Whether this is a domain-specific skill (`true`) or the core
  /// project-wide skill (`false`).
  final bool isDomain;

  /// Domain-scoped analysis facts. Only present when [isDomain] is
  /// `true`.
  final DomainFacts? domainFacts;
}

/// The generation plan: which skill files to produce.
class SkillPlan {
  /// Creates a [SkillPlan].
  const SkillPlan({required this.isSplit, required this.specs});

  /// Whether the plan calls for multiple skill files.
  final bool isSplit;

  /// The list of skill files to generate, in order.
  /// The first entry is always the core skill.
  final List<SkillSpec> specs;
}

/// Decides whether to generate a single skill file or split into
/// core + domain-specific files, and produces a [SkillPlan].
class SplitPlanner {
  /// Creates a [SplitPlanner].
  const SplitPlanner();

  /// Produces a [SkillPlan] from [facts].
  ///
  /// - If [forceSplit] is `false`, always returns a single-spec plan.
  /// - If [forceSplit] is `true`, forces split mode over every
  ///   detected feature directory (regardless of the complexity
  ///   threshold that drives `recommendedSkillFiles`).
  /// - If [forceSplit] is `null` (default), auto-detects based on the
  ///   `recommendedSkillFiles` in [facts].
  SkillPlan plan(
    ProjectFacts facts, {
    required String projectPath,
    bool? forceSplit,
  }) {
    final recommended = facts.complexity?.recommendedSkillFiles ?? ['core'];
    final shouldSplit = forceSplit ?? (recommended.length > 1);

    if (!shouldSplit) {
      return const SkillPlan(
        isSplit: false,
        specs: [SkillSpec(skillName: 'core')],
      );
    }

    // When the user forces split mode, expand to every detected
    // feature — `recommendedSkillFiles` intentionally caps at the
    // first 5 for auto-detect, but an explicit `--split` should
    // honor the full feature set.
    final domains = <String>{...recommended};
    if (forceSplit ?? false) {
      domains.addAll(facts.structure.featureDirs);
    }

    // Build domain-scoped facts for each domain.
    final domainAnalyzer = DomainAnalyzer(projectPath);
    final specs = <SkillSpec>[const SkillSpec(skillName: 'core')];

    for (final domain in domains) {
      if (domain == 'core') continue;

      final domainFacts = domainAnalyzer.analyze(domain, facts.structure);

      // Skip domains with no files found.
      if (domainFacts.files.isEmpty) continue;

      specs.add(
        SkillSpec(skillName: domain, isDomain: true, domainFacts: domainFacts),
      );
    }

    // If only core survived (all domains were empty), fall back to
    // single-file mode.
    if (specs.length == 1) {
      return const SkillPlan(
        isSplit: false,
        specs: [SkillSpec(skillName: 'core')],
      );
    }

    return SkillPlan(isSplit: true, specs: specs);
  }
}
