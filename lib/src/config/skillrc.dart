import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Known output format identifiers for skill file targets.
class OutputFormat {
  const OutputFormat._();

  /// Writes to CLAUDE.md
  static const claudeCode = 'claude_code';

  /// Writes to .cursorrules
  static const cursor = 'cursor';

  /// Writes to .github/copilot-instructions.md
  static const copilot = 'copilot';

  /// Writes to .windsurfrules
  static const windsurf = 'windsurf';

  /// Writes to `.agents/skills/<skill_name>/SKILL.md`
  static const antigravity = 'antigravity';

  /// Writes to .gemini/GEMINI.md
  static const antigravityRules = 'antigravity_rules';

  /// Writes to AGENTS.md
  static const agentsMd = 'agents_md';

  /// Writes to SKILL.md (default)
  static const generic = 'generic';

  /// All known format identifiers.
  static const all = {
    claudeCode,
    cursor,
    copilot,
    windsurf,
    antigravity,
    antigravityRules,
    agentsMd,
    generic,
  };
}

/// A single output target entry from `.skillrc.yaml`.
class OutputTarget {
  /// Creates an [OutputTarget].
  const OutputTarget({required this.format});

  /// The output format identifier.
  final String format;
}

/// Watch-mode configuration from `.skillrc.yaml`.
class WatchConfig {
  /// Creates a [WatchConfig].
  const WatchConfig({this.enabled = true, this.debounceMs = 500});

  /// Whether watch mode is enabled by default.
  final bool enabled;

  /// Debounce interval in milliseconds.
  final int debounceMs;
}

/// Reads and writes `.skillrc.yaml` project-level configuration.
///
/// This file lives at the project root and controls output targets,
/// watch mode settings, and other per-project preferences.
class Skillrc {
  /// Creates a [Skillrc] for the given [projectPath].
  Skillrc({required this.projectPath});

  /// Root path of the project.
  final String projectPath;

  /// Path to the `.skillrc.yaml` file.
  String get filePath => p.join(projectPath, '.skillrc.yaml');

  /// Whether a `.skillrc.yaml` exists at the project root.
  bool get exists => File(filePath).existsSync();

  /// Reads the config file. Returns defaults if it doesn't exist.
  SkillrcConfig read() {
    final file = File(filePath);
    if (!file.existsSync()) return const SkillrcConfig();

    try {
      final content = file.readAsStringSync();
      final doc = loadYaml(content);
      if (doc is! YamlMap) return const SkillrcConfig();
      return _parse(doc);
    } on YamlException {
      return const SkillrcConfig();
    }
  }

  /// Writes a [SkillrcConfig] to `.skillrc.yaml`.
  void write(SkillrcConfig config) {
    final buf = StringBuffer()
      ..writeln('# flutter_skill_gen project configuration')
      ..writeln('# https://pub.dev/packages/flutter_skill_gen')
      ..writeln()
      ..writeln('output_targets:');

    for (final target in config.outputTargets) {
      buf.writeln('  - format: ${target.format}');
    }

    buf
      ..writeln()
      ..writeln('watch:')
      ..writeln('  enabled: ${config.watch.enabled}')
      ..writeln('  debounce_ms: ${config.watch.debounceMs}');

    File(filePath).writeAsStringSync(buf.toString());
  }

  /// Creates a default `.skillrc.yaml` at the project root.
  void createDefault() {
    write(const SkillrcConfig());
  }

  SkillrcConfig _parse(YamlMap doc) {
    final targets = <OutputTarget>[];

    final rawTargets = doc['output_targets'];
    if (rawTargets is YamlList) {
      for (final item in rawTargets) {
        if (item is YamlMap && item['format'] is String) {
          targets.add(OutputTarget(format: item['format'] as String));
        }
      }
    }

    var watch = const WatchConfig();
    final rawWatch = doc['watch'];
    if (rawWatch is YamlMap) {
      watch = WatchConfig(
        enabled: rawWatch['enabled'] as bool? ?? true,
        debounceMs: rawWatch['debounce_ms'] as int? ?? 500,
      );
    }

    return SkillrcConfig(
      outputTargets: targets.isEmpty
          ? const [OutputTarget(format: OutputFormat.generic)]
          : targets,
      watch: watch,
    );
  }
}

/// Parsed `.skillrc.yaml` configuration.
class SkillrcConfig {
  /// Creates a [SkillrcConfig].
  const SkillrcConfig({
    this.outputTargets = const [OutputTarget(format: OutputFormat.generic)],
    this.watch = const WatchConfig(),
  });

  /// Output targets for skill file generation.
  final List<OutputTarget> outputTargets;

  /// Watch mode configuration.
  final WatchConfig watch;
}
