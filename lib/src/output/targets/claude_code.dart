import 'package:path/path.dart' as p;

import '../target_writer.dart';

/// Writes skill content to `CLAUDE.md` for Claude Code.
///
/// Multi-file layout: the core skill lands at `CLAUDE.md`, and each
/// per-feature/per-domain skill lands at `CLAUDE_<name>.md` in the
/// project root. Keeping sibling files (rather than a `.claude/`
/// subdir) matches `ManifestGenerator`'s `SKILL_<name>.md` convention
/// and avoids surprising users with a new folder.
class ClaudeCodeWriter extends FormatWriter {
  @override
  String get format => 'claude_code';

  @override
  bool get supportsMultiFile => true;

  @override
  String outputPath(String projectPath, {String? skillName}) {
    if (skillName == null || skillName == 'core') {
      return p.join(projectPath, 'CLAUDE.md');
    }
    return p.join(projectPath, 'CLAUDE_$skillName.md');
  }
}
