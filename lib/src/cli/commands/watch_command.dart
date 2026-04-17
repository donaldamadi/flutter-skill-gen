import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../config/config_manager.dart';
import '../../config/skillrc.dart';
import '../../generators/facts_writer.dart';
import '../../generators/manifest_generator.dart';
import '../../generators/skill_generator.dart';
import '../../generators/split_planner.dart';
import '../../output/target_writer.dart';
import '../../router/skill_router.dart';
import '../../scanner/project_scanner.dart';
import '../../utils/logger.dart';

/// CLI command that watches a Flutter project for file changes
/// and regenerates skill files on each change (with debounce).
///
/// In Phase 4 mode, the watcher detects the active domain from
/// changed files and writes to all configured output targets.
class WatchCommand extends Command<int> {
  /// Creates a [WatchCommand].
  WatchCommand() {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Path to the Flutter project.',
        defaultsTo: '.',
      )
      ..addOption(
        'debounce',
        abbr: 'd',
        help: 'Debounce interval in milliseconds.',
      )
      ..addFlag('verbose', abbr: 'v', help: 'Enable verbose logging.')
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
  String get name => 'watch';

  @override
  String get description =>
      'Watch for file changes and regenerate skill files '
      'automatically, writing to all configured output targets.';

  @override
  FutureOr<int>? run() async {
    final results = argResults!;
    final projectPath = p.normalize(p.absolute(results.option('path')!));
    final verbose = results.flag('verbose');
    final logger = Logger(verbose: verbose);

    // Read debounce from CLI flag or .skillrc.yaml.
    final skillrc = Skillrc(projectPath: projectPath);
    final config = skillrc.read();
    final debounceMs =
        int.tryParse(results.option('debounce') ?? '') ??
        config.watch.debounceMs;

    final libDir = Directory(p.join(projectPath, 'lib'));
    if (!libDir.existsSync()) {
      logger.error('No lib/ directory found at: $projectPath');
      return 64;
    }

    logger.info(
      'Watching $projectPath for changes '
      '(debounce: ${debounceMs}ms)...',
    );

    final targets = config.outputTargets.map((t) => t.format).join(', ');
    logger
      ..info('Output targets: $targets')
      ..info('Press Ctrl+C to stop.\n');

    // Resolve model from CLI flag or global config.
    final modelFlag = results.option('model');
    final globalConfig = ConfigManager();
    final model = modelFlag != null
        ? ConfigManager.resolveModel(modelFlag)
        : globalConfig.model;

    // Initial generation.
    await _regenerate(projectPath, config, const [], logger, model);

    // Track recently changed files for domain detection.
    final recentChanges = <String>[];
    Timer? debounceTimer;
    final watcher = libDir.watch(recursive: true);

    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
    StreamSubscription<FileSystemEvent>? pubspecWatcher;
    if (pubspecFile.existsSync()) {
      pubspecWatcher = pubspecFile.parent
          .watch()
          .where((e) => p.basename(e.path) == 'pubspec.yaml')
          .listen((_) {
            debounceTimer?.cancel();
            debounceTimer = Timer(Duration(milliseconds: debounceMs), () {
              _regenerate(
                projectPath,
                config,
                List.of(recentChanges),
                logger,
                model,
              );
              recentChanges.clear();
            });
          });
    }

    await for (final event in watcher) {
      // Only care about Dart file changes.
      if (!event.path.endsWith('.dart')) continue;

      // Skip generated files.
      if (event.path.endsWith('.g.dart') ||
          event.path.endsWith('.freezed.dart')) {
        continue;
      }

      recentChanges.add(event.path);

      debounceTimer?.cancel();
      debounceTimer = Timer(Duration(milliseconds: debounceMs), () {
        _regenerate(projectPath, config, List.of(recentChanges), logger, model);
        recentChanges.clear();
      });
    }

    await pubspecWatcher?.cancel();

    return 0;
  }

  Future<void> _regenerate(
    String projectPath,
    SkillrcConfig config,
    List<String> changedFiles,
    Logger logger,
    String model,
  ) async {
    logger.info('Change detected — regenerating...');

    final scanner = ProjectScanner(projectPath: projectPath, logger: logger);
    final facts = scanner.scan();

    if (facts == null) {
      logger.warn('Analysis failed, skipping regeneration.');
      return;
    }

    FactsWriter.write(facts, outputDir: projectPath);
    ManifestGenerator.write(facts, outputDir: projectPath);

    // Log detected domains from changed files.
    if (changedFiles.isNotEmpty) {
      final domains = DomainDetector.detectFromPaths(changedFiles);
      if (domains.isNotEmpty) {
        logger.debug('Active domains: ${domains.join(', ')}');
      }
    }

    // Plan and generate skill files.
    final configManager = ConfigManager();
    final skillGen = SkillGenerator(
      apiKey: configManager.apiKey,
      model: model,
      logger: logger,
    );

    const planner = SplitPlanner();
    final plan = planner.plan(facts, projectPath: projectPath);

    final targetWriter = TargetWriter(logger: logger);

    if (plan.isSplit) {
      final skills = await skillGen.generateAll(plan, facts);
      targetWriter.writeMultiSkill(
        skills,
        projectPath: projectPath,
        config: config,
      );
    } else {
      final content = await skillGen.generate(facts);
      targetWriter.writeToTargets(
        content,
        projectPath: projectPath,
        config: config,
      );
    }

    logger.success('Skill files updated.\n');
  }
}
