import 'package:path/path.dart' as p;

import '../target_writer.dart';

/// Writes skill content to `CLAUDE.md` for Claude Code.
class ClaudeCodeWriter extends FormatWriter {
  @override
  String get format => 'claude_code';

  @override
  bool get supportsConcatenation => true;

  @override
  String outputPath(String projectPath, {String? skillName}) =>
      p.join(projectPath, 'CLAUDE.md');
}
