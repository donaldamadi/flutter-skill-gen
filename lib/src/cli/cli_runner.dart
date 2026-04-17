import 'package:args/command_runner.dart';

import 'commands/analyze_command.dart';
import 'commands/config_command.dart';
import 'commands/hooks_command.dart';
import 'commands/init_command.dart';
import 'commands/sync_command.dart';
import 'commands/watch_command.dart';

/// The top-level CLI runner for flutter_skill_gen.
class CliRunner extends CommandRunner<int> {
  /// Creates a [CliRunner] with all registered commands.
  CliRunner()
    : super(
        'flutter_skill_gen',
        'Generate SKILL.md files for Flutter projects, '
            'giving AI coding assistants full project context '
            'from the first prompt.',
      ) {
    addCommand(AnalyzeCommand());
    addCommand(ConfigCommand());
    addCommand(HooksCommand());
    addCommand(InitCommand());
    addCommand(SyncCommand());
    addCommand(WatchCommand());
  }
}
