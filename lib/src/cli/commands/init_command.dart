import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../config/config_manager.dart';
import '../../generators/facts_writer.dart';
import '../../generators/manifest_generator.dart';
import '../../generators/skill_generator.dart';
import '../../scanner/project_scanner.dart';
import '../../templates/template_scaffolder.dart';
import '../../utils/logger.dart';

/// CLI command that scaffolds a new Flutter project from a built-in
/// template or a GitHub repository, then generates SKILL.md.
class InitCommand extends Command<int> {
  /// Creates an [InitCommand].
  InitCommand() {
    argParser
      ..addOption(
        'arch',
        help:
            'Built-in architecture template to scaffold from. '
            'Options: ${TemplateId.all.join(', ')}',
      )
      ..addOption(
        'from-repo',
        help: 'GitHub repository URL to clone and analyze.',
      )
      ..addOption(
        'name',
        abbr: 'n',
        help: 'Project name (defaults to directory name).',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help:
            'Output directory for the new project. '
            'Defaults to ./<project-name>.',
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
  String get name => 'init';

  @override
  String get description =>
      'Scaffold a new Flutter project from a template or '
      'GitHub repo, then generate SKILL.md.';

  @override
  FutureOr<int>? run() async {
    final results = argResults!;
    final arch = results.option('arch');
    final fromRepo = results.option('from-repo');
    final verbose = results.flag('verbose');
    final logger = Logger(verbose: verbose);

    if (arch != null && fromRepo != null) {
      logger.error(
        'Cannot use both --arch and --from-repo. '
        'Choose one.',
      );
      return 64;
    }

    if (arch == null && fromRepo == null) {
      logger.error(
        'Specify --arch <template> or --from-repo <url>.\n'
        'Available templates: ${TemplateId.all.join(', ')}',
      );
      return 64;
    }

    final modelFlag = results.option('model');
    final modelOverride = modelFlag != null
        ? ConfigManager.resolveModel(modelFlag)
        : null;

    if (fromRepo != null) {
      return _initFromRepo(
        fromRepo,
        results,
        logger,
        modelOverride: modelOverride,
      );
    }

    return _initFromTemplate(
      arch!,
      results,
      logger,
      modelOverride: modelOverride,
    );
  }

  Future<int> _initFromTemplate(
    String arch,
    dynamic results,
    Logger logger, {
    String? modelOverride,
  }) async {
    if (!TemplateId.all.contains(arch)) {
      logger.error(
        'Unknown template: $arch. '
        'Available: ${TemplateId.all.join(', ')}',
      );
      return 64;
    }

    final projectName =
        results.option('name') as String? ??
        '${arch.replaceAll('clean_', '')}_app';
    final outputPath =
        results.option('output') as String? ??
        p.join(Directory.current.path, projectName);

    final scaffolder = TemplateScaffolder(
      templateId: arch,
      projectName: projectName,
      outputPath: outputPath,
      logger: logger,
    );

    if (!scaffolder.scaffold()) {
      return 1;
    }

    // Analyze the scaffolded project and generate SKILL.md.
    return _analyzeAndGenerate(
      outputPath,
      logger,
      modelOverride: modelOverride,
    );
  }

  Future<int> _initFromRepo(
    String repoUrl,
    dynamic results,
    Logger logger, {
    String? modelOverride,
  }) async {
    // Derive project name from repo URL.
    final repoName = _repoNameFromUrl(repoUrl);
    final projectName = results.option('name') as String? ?? repoName;
    final outputPath =
        results.option('output') as String? ??
        p.join(Directory.current.path, projectName);

    logger.info('Cloning $repoUrl into $outputPath...');

    final cloneResult = await Process.run('git', [
      'clone',
      '--depth',
      '1',
      repoUrl,
      outputPath,
    ]);

    if (cloneResult.exitCode != 0) {
      logger.error('git clone failed: ${cloneResult.stderr}');
      return 1;
    }

    logger.success('Cloned successfully.');

    // Remove .git directory so it's a fresh project.
    final gitDir = Directory(p.join(outputPath, '.git'));
    if (gitDir.existsSync()) {
      gitDir.deleteSync(recursive: true);
      logger.debug('Removed .git directory.');
    }

    return _analyzeAndGenerate(
      outputPath,
      logger,
      modelOverride: modelOverride,
    );
  }

  Future<int> _analyzeAndGenerate(
    String projectPath,
    Logger logger, {
    String? modelOverride,
  }) async {
    logger.info('Analyzing project...');

    final scanner = ProjectScanner(projectPath: projectPath, logger: logger);
    final facts = scanner.scan();

    if (facts == null) {
      logger.warn(
        'Could not analyze the project. '
        'Ensure it has a valid pubspec.yaml.',
      );
      return 0; // Non-fatal: scaffolding succeeded.
    }

    final factsPath = FactsWriter.write(facts, outputDir: projectPath);
    logger.success('Generated $factsPath');

    final config = ConfigManager();
    final model = modelOverride ?? config.model;
    final skillGen = SkillGenerator(
      apiKey: config.apiKey,
      model: model,
      logger: logger,
    );

    final skillPath = await skillGen.generateAndWrite(
      facts,
      outputDir: projectPath,
    );
    logger.success('Generated $skillPath');

    final manifestPath = ManifestGenerator.write(facts, outputDir: projectPath);
    logger
      ..success('Generated $manifestPath')
      ..info('')
      ..success('Project ready! cd ${p.basename(projectPath)} to get started.');

    return 0;
  }

  String _repoNameFromUrl(String url) {
    // Handle both HTTPS and SSH URLs.
    var name = url.split('/').last;
    if (name.endsWith('.git')) {
      name = name.substring(0, name.length - 4);
    }
    return name;
  }
}
