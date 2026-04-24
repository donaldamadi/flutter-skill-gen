import 'package:path/path.dart' as p;

import '../target_writer.dart';

/// Writes skill content to `SKILL.md` for manual use or tools
/// without a specific convention.
///
/// Multi-file layout: the core skill lands at `SKILL.md`, and each
/// per-feature/per-domain skill lands at `SKILL_<name>.md` in the
/// project root. This matches the layout promised by
/// `ManifestGenerator` — so when `.skill_manifest.yaml` references
/// `SKILL_auth.md`, that file actually exists.
class GenericWriter extends FormatWriter {
  @override
  String get format => 'generic';

  @override
  bool get supportsMultiFile => true;

  @override
  String outputPath(String projectPath, {String? skillName}) {
    if (skillName == null || skillName == 'core') {
      return p.join(projectPath, 'SKILL.md');
    }
    return p.join(projectPath, 'SKILL_$skillName.md');
  }
}
