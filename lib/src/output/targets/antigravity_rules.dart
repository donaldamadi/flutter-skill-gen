import 'package:path/path.dart' as p;

import '../target_writer.dart';

/// Writes skill content to `.gemini/GEMINI.md` for
/// Antigravity project-level rules.
class AntigravityRulesWriter extends FormatWriter {
  @override
  String get format => 'antigravity_rules';

  @override
  String outputPath(String projectPath, {String? skillName}) =>
      p.join(projectPath, '.gemini', 'GEMINI.md');
}
