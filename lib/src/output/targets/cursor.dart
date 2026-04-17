import 'package:path/path.dart' as p;

import '../target_writer.dart';

/// Writes skill content to `.cursorrules` for Cursor.
class CursorWriter extends FormatWriter {
  @override
  String get format => 'cursor';

  @override
  String outputPath(String projectPath, {String? skillName}) =>
      p.join(projectPath, '.cursorrules');
}
