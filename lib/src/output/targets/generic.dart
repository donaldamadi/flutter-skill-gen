import 'package:path/path.dart' as p;

import '../target_writer.dart';

/// Writes skill content to `SKILL.md` for manual use or
/// tools without a specific convention.
class GenericWriter extends FormatWriter {
  @override
  String get format => 'generic';

  @override
  bool get supportsConcatenation => true;

  @override
  String outputPath(String projectPath, {String? skillName}) =>
      p.join(projectPath, 'SKILL.md');
}
