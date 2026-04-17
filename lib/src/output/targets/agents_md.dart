import 'package:path/path.dart' as p;

import '../target_writer.dart';

/// Writes skill content to `AGENTS.md` — a cross-tool standard
/// read by Antigravity, Cursor, and Claude Code.
class AgentsMdWriter extends FormatWriter {
  @override
  String get format => 'agents_md';

  @override
  bool get supportsConcatenation => true;

  @override
  String outputPath(String projectPath, {String? skillName}) =>
      p.join(projectPath, 'AGENTS.md');
}
