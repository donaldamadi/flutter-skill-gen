import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../skill/agent_skill_asset.dart';
import '../../utils/logger.dart';

/// CLI command that installs the bundled Agent Skill, so Claude Code
/// can drive skill generation itself without an API key.
class InstallSkillCommand extends Command<int> {
  /// Creates an [InstallSkillCommand].
  InstallSkillCommand() {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Project to install the skill into.',
        defaultsTo: '.',
      )
      ..addOption(
        'agent',
        abbr: 'a',
        help:
            'Which agent to install for. '
            'Options: ${SkillLocation.accepted.join(', ')}. '
            'The default installs to both .claude/skills/ and '
            '.agents/skills/, which covers every agent that '
            'implements the Agent Skills standard.',
        defaultsTo: 'all',
      )
      ..addFlag(
        'global',
        abbr: 'g',
        help:
            'Install into your home directory so the skill is '
            'available in every project, rather than into this '
            'project only.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help:
            'Install into an explicit directory instead of the '
            "agents' standard skill locations.",
      )
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Overwrite an existing SKILL.md at the target.',
      );
  }

  @override
  String get name => 'install-skill';

  @override
  String get description =>
      'Install the Agent Skill that lets Claude Code generate skill '
      'files directly, with no API key.';

  @override
  FutureOr<int>? run() {
    final results = argResults!;
    const logger = Logger();

    final explicit = results.option('output');
    final isGlobal = results.flag('global');
    final force = results.flag('force');

    final List<String> directories;
    if (explicit != null) {
      directories = [p.normalize(p.absolute(explicit))];
    } else {
      final locations = SkillLocation.tryParse(results.option('agent')!);
      if (locations == null) {
        logger.error(
          'Unknown agent: ${results.option('agent')}. '
          'Options: ${SkillLocation.accepted.join(', ')}',
        );
        return 64;
      }
      final projectPath = p.normalize(p.absolute(results.option('path')!));
      directories = [
        for (final location in locations)
          isGlobal
              ? AgentSkillAsset.globalDir(location: location)
              : AgentSkillAsset.projectDir(projectPath, location: location),
      ];
    }

    // Check every target before writing any of them, so a run either
    // installs everywhere it was asked to or changes nothing.
    final blocked = [
      for (final directory in directories)
        if (File(p.join(directory, 'SKILL.md')).existsSync() && !force)
          p.join(directory, 'SKILL.md'),
    ];
    if (blocked.isNotEmpty) {
      logger.error(
        '${blocked.join('\n')}\n'
        'already exists. Re-run with --force to overwrite.',
      );
      return 73;
    }

    for (final directory in directories) {
      logger.success('Installed ${AgentSkillAsset.install(directory)}');
    }

    logger
      ..info('')
      ..info(
        'Start a new session in your coding agent and ask it to '
        'update your project context. It will run '
        '"flutter_skill_gen prompt", write the drafts, and run '
        '"flutter_skill_gen assemble".',
      );

    return 0;
  }
}
