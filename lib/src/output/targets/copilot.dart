import 'package:path/path.dart' as p;

import '../target_writer.dart';

/// Writes skill content to `.github/copilot-instructions.md`
/// for GitHub Copilot.
class CopilotWriter extends FormatWriter {
  @override
  String get format => 'copilot';

  @override
  bool get supportsConcatenation => true;

  @override
  String outputPath(String projectPath, {String? skillName}) =>
      p.join(projectPath, '.github', 'copilot-instructions.md');
}
