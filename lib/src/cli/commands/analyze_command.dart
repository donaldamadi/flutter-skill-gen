import 'dart:async';

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

/// CLI command that scans a Flutter project and generates
/// `.skill_facts.json`, `SKILL.md`, `.skill_manifest.yaml`,
/// and writes to all configured output targets.
class AnalyzeCommand extends Command<int> {
  /// Creates an [AnalyzeCommand].
  AnalyzeCommand() {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Path to the Flutter project to analyze.',
        defaultsTo: '.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help:
            'Output directory for generated files. '
            'Defaults to the project path.',
      )
      ..addFlag(
        'facts-only',
        help:
            'Only generate .skill_facts.json, skip '
            'SKILL.md and manifest.',
      )
      ..addFlag('verbose', abbr: 'v', help: 'Enable verbose logging.')
      ..addFlag(
        'split',
        help:
            'Split output into core + domain skill files. '
            'Auto-detected by default based on project '
            'complexity. Use --no-split to force single file.',
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
  String get name => 'analyze';

  @override
  String get description =>
      'Analyze a Flutter project and generate '
      'SKILL.md with full project context.';

  @override
  FutureOr<int>? run() async {
    final results = argResults!;
    final projectPath = p.normalize(p.absolute(results.option('path')!));
    final outputDir = results.option('output') ?? projectPath;
    final factsOnly = results.flag('facts-only');
    final verbose = results.flag('verbose');
    final splitFlag = results.wasParsed('split') ? results.flag('split') : null;

    final logger = Logger(verbose: verbose)
      ..info('Analyzing Flutter project at: $projectPath');

    // Phase 1: Scan project and write facts.
    final scanner = ProjectScanner(projectPath: projectPath, logger: logger);
    final facts = scanner.scan();

    if (facts == null) {
      logger.error(
        'Analysis failed. Ensure the path contains a '
        'valid Flutter/Dart project with a pubspec.yaml.',
      );
      return 64;
    }

    final factsPath = FactsWriter.write(facts, outputDir: outputDir);
    logger.success('Generated $factsPath');

    if (factsOnly) {
      _printSummary(facts, logger);
      return 0;
    }

    // Phase 2: Plan and generate skill files.
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

    // Generate manifest.
    final manifestPath = ManifestGenerator.write(facts, outputDir: outputDir);
    logger.success('Generated $manifestPath');

    // Write to all configured output targets.
    final skillrc = Skillrc(projectPath: projectPath);
    final rcConfig = skillrc.read();
    final targetWriter = TargetWriter(logger: logger);

    if (plan.isSplit) {
      logger.info(
        'Split mode: generating ${plan.specs.length} '
        'skill files...',
      );
      final skills = await skillGen.generateAll(plan, facts);
      targetWriter.writeMultiSkill(
        skills,
        projectPath: outputDir,
        config: rcConfig,
      );
    } else {
      final content = await skillGen.generate(facts);
      targetWriter.writeToTargets(
        content,
        projectPath: outputDir,
        config: rcConfig,
      );
    }

    logger.success(
      'Wrote to ${rcConfig.outputTargets.length} output '
      'target(s)',
    );

    _printSummary(facts, logger, split: plan.isSplit);

    return 0;
  }

  void _printSummary(ProjectFacts facts, Logger logger, {bool split = false}) {
    logger
      ..info('')
      ..info('Project: ${facts.projectName}');
    if (facts.patterns.architecture != null) {
      logger.info('Architecture: ${facts.patterns.architecture}');
    }
    if (facts.patterns.stateManagement != null) {
      logger.info(
        'State Management: '
        '${facts.patterns.stateManagement}',
      );
    }
    if (facts.structure.organization != 'unknown') {
      logger.info('Organization: ${facts.structure.organization}');
    }
    if (facts.complexity != null) {
      logger.info(
        'Complexity: '
        '${facts.complexity!.estimatedMagnitude} '
        '(${facts.complexity!.totalDartFiles} files, '
        '${facts.complexity!.totalFeatures} features)',
      );
    }
    if (split) {
      logger.info('Mode: split (core + domain skills)');
    }
  }
}
