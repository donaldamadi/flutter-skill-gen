import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../ci/git_hooks_installer.dart';
import '../../ci/github_action_generator.dart';
import '../../utils/logger.dart';

/// CLI command for managing CI hooks and GitHub Actions.
///
/// Supports installing/removing git hooks and generating
/// a GitHub Actions workflow for automated skill sync.
class HooksCommand extends Command<int> {
  /// Creates a [HooksCommand].
  HooksCommand() {
    argParser
      ..addFlag(
        'install',
        abbr: 'i',
        help: 'Install pre-commit and post-merge git hooks.',
      )
      ..addFlag('remove', help: 'Remove flutter_skill_gen git hooks.')
      ..addFlag(
        'github-action',
        help:
            'Generate a GitHub Actions workflow for '
            'automated skill sync.',
      )
      ..addFlag(
        'status',
        abbr: 's',
        help: 'Show which hooks are currently installed.',
      )
      ..addFlag(
        'dart-only',
        help:
            'Use Dart SDK only (no Flutter) in the '
            'GitHub Action.',
      )
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Path to the project.',
        defaultsTo: '.',
      )
      ..addFlag('verbose', abbr: 'v', help: 'Enable verbose logging.');
  }

  @override
  String get name => 'hooks';

  @override
  String get description =>
      'Manage git hooks and CI integration for '
      'automated skill sync.';

  @override
  int run() {
    final results = argResults!;
    final projectPath = p.normalize(p.absolute(results.option('path')!));
    final verbose = results.flag('verbose');
    final logger = Logger(verbose: verbose);

    final install = results.flag('install');
    final remove = results.flag('remove');
    final githubAction = results.flag('github-action');
    final status = results.flag('status');

    if (install && remove) {
      logger.error('Cannot use --install and --remove together.');
      return 64;
    }

    var didAction = false;

    if (install) {
      didAction = true;
      _installHooks(projectPath, logger);
    }

    if (remove) {
      didAction = true;
      _removeHooks(projectPath, logger);
    }

    if (githubAction) {
      didAction = true;
      final dartOnly = results.flag('dart-only');
      _generateGitHubAction(
        projectPath,
        usesFlutter: !dartOnly,
        logger: logger,
      );
    }

    if (status || !didAction) {
      _showStatus(projectPath, logger);
    }

    return 0;
  }

  void _installHooks(String projectPath, Logger logger) {
    final dir = GitHooksInstaller.hooksDir(projectPath);
    if (dir == null) {
      logger.error(
        'Not a git repository: $projectPath\n'
        'Run "git init" first.',
      );
      return;
    }

    final results = GitHooksInstaller.installAll(projectPath: projectPath);

    for (final entry in results.entries) {
      if (entry.value) {
        logger.success('Installed ${entry.key} hook.');
      } else {
        logger.error('Failed to install ${entry.key} hook.');
      }
    }
  }

  void _removeHooks(String projectPath, Logger logger) {
    final results = GitHooksInstaller.removeAll(projectPath: projectPath);

    for (final entry in results.entries) {
      if (entry.value) {
        logger.success('Removed ${entry.key} hook.');
      } else {
        logger.info('${entry.key}: no flutter_skill_gen hook found.');
      }
    }
  }

  void _generateGitHubAction(
    String projectPath, {
    required bool usesFlutter,
    required Logger logger,
  }) {
    final path = GitHubActionGenerator.write(
      projectPath: projectPath,
      usesFlutter: usesFlutter,
    );
    logger
      ..success('Generated $path')
      ..info(
        'Add FLUTTER_SKILL_API_KEY to your repo secrets '
        'for AI-powered generation.',
      );
  }

  void _showStatus(String projectPath, Logger logger) {
    final hookStatus = GitHooksInstaller.status(projectPath: projectPath);

    logger.info('Git hooks:');
    for (final entry in hookStatus.entries) {
      final icon = entry.value ? '[OK]' : '[ ]';
      logger.info('  $icon ${entry.key}');
    }

    // Check for GitHub Action.
    final actionPath = p.join(projectPath, GitHubActionGenerator.defaultPath);
    final hasAction = File(actionPath).existsSync();
    logger
      ..info('')
      ..info('GitHub Action:');
    final icon = hasAction ? '[OK]' : '[ ]';
    logger.info('  $icon ${GitHubActionGenerator.defaultPath}');

    if (!hasAction) {
      logger
        ..info('')
        ..info('Run: flutter_skill_gen hooks --github-action');
    }
  }
}
