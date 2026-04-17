import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../config/config_manager.dart';
import '../../config/skillrc.dart';
import '../../utils/logger.dart';

/// CLI command to manage flutter_skill_gen configuration.
///
/// Handles both global config (`~/.flutter_skill_gen/config.yaml`)
/// and per-project config (`.skillrc.yaml`).
class ConfigCommand extends Command<int> {
  /// Creates a [ConfigCommand].
  ConfigCommand() {
    argParser
      ..addOption('set-key', help: 'Set the Claude API key.')
      ..addOption('set-model', help: 'Set the Claude model ID.')
      ..addFlag('remove-key', help: 'Remove the stored API key.')
      ..addOption(
        'add-target',
        help:
            'Add an output target to .skillrc.yaml. '
            'Options: ${OutputFormat.all.join(', ')}',
      )
      ..addOption(
        'remove-target',
        help: 'Remove an output target from .skillrc.yaml.',
      )
      ..addFlag(
        'init-skillrc',
        help:
            'Create a default .skillrc.yaml in the '
            'current directory.',
      )
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Project path for .skillrc.yaml operations.',
        defaultsTo: '.',
      )
      ..addFlag('show', help: 'Show current configuration.', defaultsTo: true);
  }

  @override
  String get name => 'config';

  @override
  String get description =>
      'Manage flutter_skill_gen configuration '
      '(API key, model, output targets).';

  @override
  int run() {
    final results = argResults!;
    final config = ConfigManager();
    const logger = Logger();
    final projectPath = p.normalize(p.absolute(results.option('path')!));

    final setKey = results.option('set-key');
    final setModel = results.option('set-model');
    final removeKey = results.flag('remove-key');
    final addTarget = results.option('add-target');
    final removeTarget = results.option('remove-target');
    final initSkillrc = results.flag('init-skillrc');

    var didAction = false;

    if (setKey != null) {
      config.setApiKey(setKey);
      logger.success('API key saved.');
      didAction = true;
    }

    if (setModel != null) {
      config.setModel(setModel);
      logger.success('Model set to: $setModel');
      didAction = true;
    }

    if (removeKey) {
      config.removeApiKey();
      logger.success('API key removed.');
      didAction = true;
    }

    if (initSkillrc) {
      final skillrc = Skillrc(projectPath: projectPath)..createDefault();
      logger.success('Created ${skillrc.filePath}');
      didAction = true;
    }

    if (addTarget != null) {
      _addOutputTarget(projectPath, addTarget, logger);
      didAction = true;
    }

    if (removeTarget != null) {
      _removeOutputTarget(projectPath, removeTarget, logger);
      didAction = true;
    }

    if (!didAction) {
      _showConfig(config, projectPath, logger);
    }

    return 0;
  }

  void _addOutputTarget(String projectPath, String format, Logger logger) {
    if (!OutputFormat.all.contains(format)) {
      logger.error(
        'Unknown output format: $format. '
        'Options: ${OutputFormat.all.join(', ')}',
      );
      return;
    }

    final skillrc = Skillrc(projectPath: projectPath);
    final existing = skillrc.read();

    final alreadyExists = existing.outputTargets.any((t) => t.format == format);
    if (alreadyExists) {
      logger.info('Target "$format" already configured.');
      return;
    }

    final updatedTargets = [
      ...existing.outputTargets,
      OutputTarget(format: format),
    ];

    skillrc.write(
      SkillrcConfig(outputTargets: updatedTargets, watch: existing.watch),
    );
    logger.success('Added output target: $format');
  }

  void _removeOutputTarget(String projectPath, String format, Logger logger) {
    final skillrc = Skillrc(projectPath: projectPath);
    if (!skillrc.exists) {
      logger.error(
        'No .skillrc.yaml found at $projectPath. '
        'Run: flutter_skill_gen config --init-skillrc',
      );
      return;
    }

    final existing = skillrc.read();
    final updatedTargets = existing.outputTargets
        .where((t) => t.format != format)
        .toList();

    if (updatedTargets.length == existing.outputTargets.length) {
      logger.info('Target "$format" not found in config.');
      return;
    }

    // Ensure at least one target remains.
    if (updatedTargets.isEmpty) {
      updatedTargets.add(const OutputTarget(format: OutputFormat.generic));
    }

    skillrc.write(
      SkillrcConfig(outputTargets: updatedTargets, watch: existing.watch),
    );
    logger.success('Removed output target: $format');
  }

  void _showConfig(ConfigManager config, String projectPath, Logger logger) {
    logger
      ..info('Global config (${config.configPath}):')
      ..info('');

    if (config.hasApiKey) {
      final key = config.apiKey!;
      final masked = key.length > 12
          ? '${key.substring(0, 8)}...'
                '${key.substring(key.length - 4)}'
          : '****';
      logger.info('  api_key: $masked');
    } else {
      logger.info('  api_key: (not set)');
    }

    logger.info('  model:   ${config.model}');

    // Show project config if present.
    final skillrc = Skillrc(projectPath: projectPath);
    if (skillrc.exists) {
      final rc = skillrc.read();
      logger
        ..info('')
        ..info('Project config (${skillrc.filePath}):')
        ..info('');
      final formats = rc.outputTargets.map((t) => t.format).join(', ');
      logger
        ..info('  output_targets: $formats')
        ..info('  watch.enabled:    ${rc.watch.enabled}')
        ..info('  watch.debounce_ms: ${rc.watch.debounceMs}');
    }

    if (!config.hasApiKey) {
      logger
        ..info('')
        ..info(
          'Set your API key with: '
          'flutter_skill_gen config --set-key <key>',
        );
    }

    exit(0);
  }
}
