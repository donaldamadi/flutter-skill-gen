import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// A single skill entry parsed from `.skill_manifest.yaml`.
class SkillEntry {
  /// Creates a [SkillEntry].
  const SkillEntry({
    required this.file,
    required this.scope,
    this.alwaysInject = false,
    this.injectWhen,
  });

  /// The skill file name (e.g. `SKILL.md`, `SKILL_auth.md`).
  final String file;

  /// Scope keywords this skill covers.
  final List<String> scope;

  /// Whether this skill should always be injected.
  final bool alwaysInject;

  /// Human-readable injection rule description.
  final String? injectWhen;
}

/// Reads and parses `.skill_manifest.yaml` into [SkillEntry] objects.
class ManifestReader {
  /// Creates a [ManifestReader] for the given [projectPath].
  ManifestReader({required this.projectPath});

  /// Root path of the project.
  final String projectPath;

  /// Path to the manifest file.
  String get manifestPath => p.join(projectPath, '.skill_manifest.yaml');

  /// Whether the manifest file exists.
  bool get exists => File(manifestPath).existsSync();

  /// Reads and parses the manifest. Returns empty list on error.
  List<SkillEntry> read() {
    final file = File(manifestPath);
    if (!file.existsSync()) return const [];

    try {
      final content = file.readAsStringSync();
      final doc = loadYaml(content);
      if (doc is! YamlMap) return const [];
      return _parse(doc);
    } on YamlException {
      return const [];
    }
  }

  /// Returns only the entries that should always be injected.
  List<SkillEntry> alwaysInjected() {
    return read().where((e) => e.alwaysInject).toList();
  }

  /// Returns entries whose scope contains any of the given
  /// [keywords] (case-insensitive).
  List<SkillEntry> matchingScope(Set<String> keywords) {
    final lower = keywords.map((k) => k.toLowerCase()).toSet();
    return read().where((entry) {
      if (entry.alwaysInject) return true;
      return entry.scope.any((s) => lower.contains(s.toLowerCase()));
    }).toList();
  }

  List<SkillEntry> _parse(YamlMap doc) {
    final skills = doc['skills'];
    if (skills is! YamlList) return const [];

    final entries = <SkillEntry>[];
    for (final item in skills) {
      if (item is! YamlMap) continue;

      final file = item['file'] as String?;
      if (file == null) continue;

      final rawScope = item['scope'];
      final scope = <String>[];
      if (rawScope is YamlList) {
        for (final s in rawScope) {
          scope.add(s.toString());
        }
      }

      entries.add(
        SkillEntry(
          file: file,
          scope: scope,
          alwaysInject: item['always_inject'] as bool? ?? false,
          injectWhen: item['inject_when'] as String?,
        ),
      );
    }

    return entries;
  }
}
