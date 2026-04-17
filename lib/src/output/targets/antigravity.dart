import 'package:path/path.dart' as p;

import '../target_writer.dart';

/// Writes skill content to `.agents/skills/<skill_name>/SKILL.md`
/// for Google Antigravity's native skills system.
///
/// Antigravity has built-in skill routing — it only loads a skill
/// into context when the request matches the skill's description.
/// The proxy defers to Antigravity's own routing for this format.
class AntigravityWriter extends FormatWriter {
  @override
  String get format => 'antigravity';

  @override
  bool get supportsMultiFile => true;

  @override
  String outputPath(String projectPath, {String? skillName}) {
    final name = skillName ?? 'core';
    return p.join(projectPath, '.agents', 'skills', name, 'SKILL.md');
  }
}
