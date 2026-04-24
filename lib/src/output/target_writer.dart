import 'dart:io';

import 'package:path/path.dart' as p;

import '../config/skillrc.dart';
import '../utils/logger.dart';
import 'targets/agents_md.dart';
import 'targets/antigravity.dart';
import 'targets/antigravity_rules.dart';
import 'targets/claude_code.dart';
import 'targets/copilot.dart';
import 'targets/cursor.dart';
import 'targets/generic.dart';
import 'targets/windsurf.dart';

/// Base class for format-specific skill file writers.
abstract class FormatWriter {
  /// Creates a [FormatWriter]. Subclasses provide the concrete
  /// format behavior by overriding [format] and [outputPath].
  const FormatWriter();

  /// The output format identifier.
  String get format;

  /// Whether this format supports writing separate files per skill
  /// (e.g. `.agents/skills/<name>/SKILL.md`).
  bool get supportsMultiFile => false;

  /// Whether this format supports concatenating multiple skills into
  /// a single file with section separators.
  bool get supportsConcatenation => false;

  /// Returns the output file path relative to [projectPath].
  String outputPath(String projectPath, {String? skillName});

  /// Writes [content] to the appropriate location.
  void write(String content, {required String projectPath, String? skillName}) {
    final path = outputPath(projectPath, skillName: skillName);
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }
}

/// Dispatches skill content to all configured output targets.
class TargetWriter {
  /// Creates a [TargetWriter].
  TargetWriter({Logger? logger}) : logger = logger ?? const Logger();

  /// Logger for output.
  final Logger logger;

  /// Registry of format ID → writer instance.
  static final _writers = <String, FormatWriter>{
    OutputFormat.claudeCode: ClaudeCodeWriter(),
    OutputFormat.cursor: CursorWriter(),
    OutputFormat.copilot: CopilotWriter(),
    OutputFormat.windsurf: WindsurfWriter(),
    OutputFormat.antigravity: AntigravityWriter(),
    OutputFormat.antigravityRules: AntigravityRulesWriter(),
    OutputFormat.agentsMd: AgentsMdWriter(),
    OutputFormat.generic: GenericWriter(),
  };

  /// Writes [content] to all targets specified in [config].
  ///
  /// [skillName] is used by formats that support per-skill files
  /// (e.g. Antigravity).
  void writeToTargets(
    String content, {
    required String projectPath,
    required SkillrcConfig config,
    String? skillName,
  }) {
    for (final target in config.outputTargets) {
      final writer = _writers[target.format];
      if (writer == null) {
        logger.warn('Unknown output format: ${target.format}, skipping.');
        continue;
      }

      writer.write(content, projectPath: projectPath, skillName: skillName);

      final path = writer.outputPath(projectPath, skillName: skillName);
      logger.debug('  Wrote ${p.relative(path, from: projectPath)}');
    }
  }

  /// Writes multiple skill files to all configured targets.
  ///
  /// [skills] maps skill names (e.g. "core", "auth") to their
  /// markdown content. Dispatch strategy per writer:
  ///
  /// - `supportsMultiFile`: one `write()` call per skill with
  ///   its `skillName`.
  /// - `supportsConcatenation`: all skills concatenated into a
  ///   single file with section headers.
  /// - Neither: only the "core" entry is written.
  void writeMultiSkill(
    Map<String, String> skills, {
    required String projectPath,
    required SkillrcConfig config,
  }) {
    for (final target in config.outputTargets) {
      final writer = _writers[target.format];
      if (writer == null) {
        logger.warn('Unknown output format: ${target.format}, skipping.');
        continue;
      }

      if (writer.supportsMultiFile) {
        // Write each skill as a separate file.
        for (final entry in skills.entries) {
          writer.write(
            entry.value,
            projectPath: projectPath,
            skillName: entry.key,
          );
          final path = writer.outputPath(projectPath, skillName: entry.key);
          logger.debug('  Wrote ${p.relative(path, from: projectPath)}');
        }
      } else if (writer.supportsConcatenation) {
        // Concatenate all skills into a single file.
        final buf = StringBuffer();
        var first = true;
        for (final entry in skills.entries) {
          if (!first) {
            buf
              ..writeln()
              ..writeln('---')
              ..writeln()
              ..writeln('<!-- domain: ${entry.key} -->')
              ..writeln();
          }
          buf.write(entry.value);
          first = false;
        }

        writer.write(buf.toString(), projectPath: projectPath);
        final path = writer.outputPath(projectPath);
        logger.debug('  Wrote ${p.relative(path, from: projectPath)}');
      } else {
        // Core-only: write just the core skill.
        final coreContent = skills.entries
            .firstWhere(
              (e) => e.key == 'core',
              orElse: () => skills.entries.first,
            )
            .value;
        writer.write(coreContent, projectPath: projectPath);
        final path = writer.outputPath(projectPath);
        logger.debug(
          '  Wrote ${p.relative(path, from: projectPath)} '
          '(core only)',
        );
      }
    }
  }

  /// Returns the [FormatWriter] for a given format ID, or `null`.
  static FormatWriter? writerFor(String format) => _writers[format];

  /// Returns all registered format IDs.
  static Set<String> get registeredFormats => _writers.keys.toSet();
}
