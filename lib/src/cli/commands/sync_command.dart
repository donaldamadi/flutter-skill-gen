import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../config/config_manager.dart';
import '../../config/skillrc.dart';
import '../../generators/facts_writer.dart';
import '../../generators/manifest_generator.dart';
import '../../generators/skill_generator.dart';
import '../../generators/split_planner.dart';
import '../../models/project_facts.dart';
import '../../output/target_writer.dart';
import '../../scanner/project_scanner.dart';
import '../../utils/logger.dart';

/// CLI command that re-analyzes a project and regenerates all
/// skill files, writing to all configured output targets.
class SyncCommand extends Command<int> {
  /// Creates a [SyncCommand].
  SyncCommand() {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Path to the Flutter project.',
        defaultsTo: '.',
      )
      ..addFlag(
        'ci',
        help:
            'CI mode: non-interactive, exit code 1 on '
            'analysis failure.',
      )
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Force regeneration even if facts have not changed.',
      )
      ..addFlag('verbose', abbr: 'v', help: 'Enable verbose logging.')
      ..addFlag(
        'split',
        help:
            'Split output into core + domain skill files. '
            'Auto-detected by default.',
        defaultsTo: null,
      )
      ..addOption(
        'model',
        abbr: 'm',
        help:
            'Claude model for AI generation. '
            'Shortcuts: "sonnet", "opus". '
            'Or pass a full model ID.',
      );
  }

  @override
  String get name => 'sync';

  @override
  String get description =>
      'Re-analyze the project and regenerate SKILL.md '
      'and all skill files.';

  @override
  FutureOr<int>? run() async {
    final results = argResults!;
    final projectPath = p.normalize(p.absolute(results.option('path')!));
    final ci = results.flag('ci');
    final force = results.flag('force');
    final verbose = results.flag('verbose');
    final splitFlag = results.wasParsed('split') ? results.flag('split') : null;

    final logger = Logger(verbose: verbose)
      ..info('Syncing skill files for: $projectPath');

    final scanner = ProjectScanner(projectPath: projectPath, logger: logger);
    final facts = scanner.scan();

    if (facts == null) {
      logger.error(
        'Analysis failed. Ensure the path contains a '
        'valid Flutter/Dart project with a pubspec.yaml.',
      );
      return ci ? 1 : 64;
    }

    // Diff against previous facts to avoid unnecessary regeneration.
    if (!force && _factsUnchanged(facts, projectPath, logger)) {
      logger.success('Project facts unchanged — skipping regeneration.');
      return 0;
    }

    // Write facts.
    final factsPath = FactsWriter.write(facts, outputDir: projectPath);
    logger.success('Updated $factsPath');

    // Plan before writing the manifest — the manifest references
    // only the skill files the plan will actually produce.
    final config = ConfigManager();
    final modelFlag = results.option('model');
    final model = modelFlag != null
        ? ConfigManager.resolveModel(modelFlag)
        : config.model;

    final skillGen = SkillGenerator(
      apiKey: config.apiKey,
      model: model,
      logger: logger,
    );

    const planner = SplitPlanner();
    final plan = planner.plan(
      facts,
      projectPath: projectPath,
      forceSplit: splitFlag,
    );

    // Regenerate manifest, grounded in the plan.
    final manifestPath = ManifestGenerator.write(
      facts,
      outputDir: projectPath,
      plan: plan,
    );
    logger.success('Updated $manifestPath');

    // Write to all configured output targets.
    final skillrc = Skillrc(projectPath: projectPath);
    final rcConfig = skillrc.read();
    final targetWriter = TargetWriter(logger: logger);

    if (plan.isSplit) {
      final skills = await skillGen.generateAll(plan, facts);
      targetWriter.writeMultiSkill(
        skills,
        projectPath: projectPath,
        config: rcConfig,
      );
    } else {
      final content = await skillGen.generate(facts);
      targetWriter.writeToTargets(
        content,
        projectPath: projectPath,
        config: rcConfig,
      );
    }

    logger
      ..success(
        'Wrote to ${rcConfig.outputTargets.length} output '
        'target(s)',
      )
      ..info('')
      ..success('Sync complete.');

    return 0;
  }

  /// Compares [newFacts] against the existing `.skill_facts.json`.
  ///
  /// Ignores `generated_at` and `tool_version` which change on
  /// every run and don't reflect actual project changes.
  bool _factsUnchanged(
    ProjectFacts newFacts,
    String projectPath,
    Logger logger,
  ) {
    final existingFile = File(p.join(projectPath, FactsWriter.defaultFileName));
    if (!existingFile.existsSync()) return false;

    try {
      final existingJson =
          jsonDecode(existingFile.readAsStringSync()) as Map<String, dynamic>;
      final newJson = newFacts.toJson();

      // Strip volatile fields before comparison.
      String toComparable(Map<String, dynamic> m) {
        final copy = Map<String, dynamic>.from(m)
          ..remove('generated_at')
          ..remove('tool_version');
        return jsonEncode(copy);
      }

      return toComparable(existingJson) == toComparable(newJson);
    } on FormatException {
      logger.debug('Existing facts file is corrupt — regenerating.');
      return false;
    } on FileSystemException {
      return false;
    }
  }
}
