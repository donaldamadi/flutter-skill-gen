import 'package:path/path.dart' as p;

import '../target_writer.dart';

/// Writes skill content to `.windsurfrules` for Windsurf.
class WindsurfWriter extends FormatWriter {
  @override
  String get format => 'windsurf';

  @override
  String outputPath(String projectPath, {String? skillName}) =>
      p.join(projectPath, '.windsurfrules');
}
