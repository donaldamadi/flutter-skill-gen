import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../generators/split_planner.dart';
import '../models/project_facts.dart';

/// The handoff directory shared by `prompt` and `assemble`.
///
/// `prompt` fills it with everything an external author needs — the
/// scanned facts, one prompt per planned skill file, and a plan
/// describing which scopes are expected. The author writes drafts
/// into `drafts/`, and `assemble` reads the whole thing back.
///
/// Facts live here rather than at the project root on purpose: a
/// `prompt` run that is never assembled must not update
/// `.skill_facts.json`, or the next `sync` would see no change and
/// skip regenerating a SKILL.md that is still stale.
class SkillWorkspace {
  /// Creates a [SkillWorkspace] rooted at [directory].
  SkillWorkspace({required this.directory});

  /// Absolute path of the workspace directory.
  final String directory;

  /// Default workspace directory name, relative to the project root.
  static const defaultDirName = '.skill_work';

  /// Version stamped into `plan.json`, so a future layout change can
  /// reject a stale workspace instead of misreading it.
  static const planVersion = 1;

  /// Path of the plan file describing the expected scopes.
  String get planPath => p.join(directory, 'plan.json');

  /// Path of the scanned project facts.
  String get factsPath => p.join(directory, 'facts.json');

  /// Directory holding one prompt per skill scope.
  String get promptsDir => p.join(directory, 'prompts');

  /// Directory the external author writes drafts into.
  String get draftsDir => p.join(directory, 'drafts');

  /// Path of the prompt for [scope].
  String promptPath(String scope) => p.join(promptsDir, '$scope.md');

  /// Path of the draft for [scope].
  String draftPath(String scope) => p.join(draftsDir, '$scope.md');

  /// Whether a workspace has been created here.
  bool get exists => File(planPath).existsSync();

  /// Creates the workspace directories, clearing any previous run.
  ///
  /// Stale prompts and drafts from an earlier run describe an earlier
  /// state of the project, so they are removed rather than merged.
  void reset() {
    final dir = Directory(directory);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    Directory(promptsDir).createSync(recursive: true);
    Directory(draftsDir).createSync(recursive: true);
  }

  /// Deletes the workspace entirely.
  void delete() {
    final dir = Directory(directory);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  /// Writes [facts] as the ground truth for this run.
  void writeFacts(ProjectFacts facts) {
    File(factsPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(facts.toJson()),
    );
  }

  /// Reads back the facts written by `prompt`.
  ///
  /// Throws [WorkspaceException] when they are missing or unreadable.
  ProjectFacts readFacts() {
    final file = File(factsPath);
    if (!file.existsSync()) {
      throw WorkspaceException(
        'No facts found at $factsPath. Run "flutter_skill_gen prompt" '
        'first.',
      );
    }
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) {
        throw WorkspaceException('$factsPath is not a JSON object.');
      }
      return ProjectFacts.fromJson(decoded);
    } on FormatException catch (e) {
      throw WorkspaceException('Could not parse $factsPath: ${e.message}');
    }
  }

  /// Writes the plan describing which scopes `assemble` will expect.
  void writePlan(
    SkillPlan plan, {
    required String projectPath,
    bool? forceSplit,
  }) {
    final json = <String, dynamic>{
      'version': planVersion,
      'project_path': projectPath,
      'split': plan.isSplit,
      'force_split': forceSplit,
      'scopes': [
        for (final spec in plan.specs)
          {'name': spec.skillName, 'domain': spec.isDomain},
      ],
    };
    File(
      planPath,
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
  }

  /// Reads the plan written by `prompt`.
  ///
  /// Throws [WorkspaceException] when it is missing, unreadable, or
  /// written by an incompatible version.
  WorkspacePlan readPlan() {
    final file = File(planPath);
    if (!file.existsSync()) {
      throw WorkspaceException(
        'No workspace found at $directory. Run '
        '"flutter_skill_gen prompt" first.',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException catch (e) {
      throw WorkspaceException('Could not parse $planPath: ${e.message}');
    }

    if (decoded is! Map<String, dynamic>) {
      throw WorkspaceException('$planPath is not a JSON object.');
    }

    final version = decoded['version'];
    if (version != planVersion) {
      throw WorkspaceException(
        '$planPath was written by an incompatible version '
        '(found $version, expected $planVersion). Re-run '
        '"flutter_skill_gen prompt".',
      );
    }

    final rawScopes = decoded['scopes'];
    final scopes = <String>[
      if (rawScopes is List)
        for (final entry in rawScopes)
          if (entry is Map && entry['name'] is String) entry['name'] as String,
    ];

    return WorkspacePlan(
      projectPath: decoded['project_path'] as String? ?? directory,
      isSplit: decoded['split'] == true,
      forceSplit: decoded['force_split'] as bool?,
      scopes: scopes,
    );
  }

  /// Writes the prompt for [scope].
  void writePrompt(String scope, String content) {
    File(promptPath(scope))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  /// Reads the draft for [scope], or `null` when none was written.
  String? readDraft(String scope) {
    final file = File(draftPath(scope));
    if (!file.existsSync()) return null;
    final content = file.readAsStringSync().trim();
    return content.isEmpty ? null : content;
  }

  /// Reads every draft named by [scopes], skipping the ones that are
  /// missing or empty.
  Map<String, String> readDrafts(Iterable<String> scopes) => {
    for (final scope in scopes)
      if (readDraft(scope) case final draft?) scope: draft,
  };
}

/// What `prompt` recorded about a run, for `assemble` to replay.
class WorkspacePlan {
  /// Creates a [WorkspacePlan].
  const WorkspacePlan({
    required this.projectPath,
    required this.isSplit,
    required this.forceSplit,
    required this.scopes,
  });

  /// Project that was scanned.
  final String projectPath;

  /// Whether the run planned multiple skill files.
  final bool isSplit;

  /// The `--split` flag as passed to `prompt`, replayed by `assemble`
  /// so the planner reaches the same decision a second time.
  final bool? forceSplit;

  /// Skill scopes the run expects drafts for, in plan order.
  final List<String> scopes;
}

/// Thrown when the handoff workspace is missing or malformed.
class WorkspaceException implements Exception {
  /// Creates a [WorkspaceException].
  const WorkspaceException(this.message);

  /// Human-readable explanation, phrased as a next step.
  final String message;

  @override
  String toString() => message;
}
