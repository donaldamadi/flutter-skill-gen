import 'manifest_reader.dart';

/// Result of routing a prompt or file context through the skill
/// classifier.
class RoutingResult {
  /// Creates a [RoutingResult].
  const RoutingResult({
    required this.selectedSkills,
    required this.matchedKeywords,
  });

  /// The skill entries selected for injection.
  final List<SkillEntry> selectedSkills;

  /// The keywords that triggered selection.
  final Set<String> matchedKeywords;
}

/// Keyword-based prompt-to-skill classifier (v1).
///
/// Reads the `.skill_manifest.yaml` and selects which skill files
/// should be injected based on keyword matches against the prompt
/// or active file paths.
class SkillRouter {
  /// Creates a [SkillRouter] with the given [manifestReader].
  SkillRouter({required this.manifestReader});

  /// The manifest reader providing skill entries.
  final ManifestReader manifestReader;

  /// Routes a prompt string to the appropriate skill files.
  ///
  /// Always includes skills marked `always_inject: true`.
  /// Additionally includes skills whose scope keywords appear
  /// in the [prompt] text (case-insensitive).
  RoutingResult routePrompt(String prompt) {
    final entries = manifestReader.read();
    if (entries.isEmpty) {
      return const RoutingResult(selectedSkills: [], matchedKeywords: {});
    }

    final promptLower = prompt.toLowerCase();
    final selected = <SkillEntry>[];
    final matched = <String>{};

    for (final entry in entries) {
      if (entry.alwaysInject) {
        selected.add(entry);
        continue;
      }

      for (final keyword in entry.scope) {
        if (promptLower.contains(keyword.toLowerCase())) {
          selected.add(entry);
          matched.add(keyword);
          break;
        }
      }
    }

    return RoutingResult(selectedSkills: selected, matchedKeywords: matched);
  }

  /// Routes based on active file paths. Extracts domain keywords
  /// from the paths (e.g. `lib/features/auth/...` → `auth`).
  RoutingResult routeFromFiles(List<String> changedFiles) {
    final keywords = DomainDetector.detectFromPaths(changedFiles);
    final entries = manifestReader.matchingScope(keywords);

    return RoutingResult(selectedSkills: entries, matchedKeywords: keywords);
  }
}

/// Detects the active domain from file paths.
///
/// Extracts feature/domain names from paths like
/// `lib/features/auth/presentation/bloc/auth_bloc.dart`.
class DomainDetector {
  const DomainDetector._();

  /// Extracts domain keywords from a list of changed file paths.
  static Set<String> detectFromPaths(List<String> paths) {
    final domains = <String>{};

    for (final path in paths) {
      final parts = path.split('/');

      // Look for features/<name>/ pattern.
      for (var i = 0; i < parts.length - 1; i++) {
        if (parts[i] == 'features' || parts[i] == 'modules') {
          domains.add(parts[i + 1]);
          break;
        }
      }

      // Also detect from layer directories.
      for (final part in parts) {
        if (_layerKeywords.contains(part)) {
          domains.add(part);
        }
      }
    }

    return domains;
  }

  static const _layerKeywords = {
    'data',
    'domain',
    'presentation',
    'core',
    'shared',
    'design_system',
  };
}
