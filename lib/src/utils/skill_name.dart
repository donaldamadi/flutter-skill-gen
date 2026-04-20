/// Utilities for generating Agent Skills spec-compliant skill names
/// and YAML frontmatter.
///
/// See https://agentskills.io/specification for the full spec.
class SkillName {
  const SkillName._();

  /// Normalizes a string into a spec-compliant skill name.
  ///
  /// Rules: lowercase, `a-z`/`0-9`/hyphens only, no leading/trailing
  /// hyphens, no consecutive hyphens, max 64 characters.
  static String normalize(String input) {
    var name = input
        .toLowerCase()
        .replaceAll('_', '-')
        .replaceAll(RegExp('[^a-z0-9-]'), '')
        .replaceAll(RegExp('-{2,}'), '-');

    // Trim leading/trailing hyphens.
    name = name.replaceAll(RegExp(r'^-+|-+$'), '');

    // Truncate to 64 chars without trailing hyphen.
    if (name.length > 64) {
      name = name.substring(0, 64).replaceAll(RegExp(r'-+$'), '');
    }

    return name;
  }

  /// Builds a skill name with a suffix: `<project>-<suffix>`.
  static String withSuffix(String projectName, String suffix) {
    final base = normalize(projectName);
    final normalizedSuffix = normalize(suffix);
    return normalize('$base-$normalizedSuffix');
  }

  /// Generates YAML frontmatter for a SKILL.md file following the
  /// Agent Skills specification.
  static String frontmatter({
    required String name,
    required String description,
  }) {
    final escapedDesc = _yamlEscape(description);
    return '---\n'
        'name: $name\n'
        'description: $escapedDesc\n'
        '---\n\n';
  }

  static String _yamlEscape(String value) {
    if (value.contains(':') ||
        value.contains('#') ||
        value.contains("'") ||
        value.contains('"') ||
        value.startsWith(' ') ||
        value.endsWith(' ')) {
      final escaped = value.replaceAll('"', r'\"');
      return '"$escaped"';
    }
    return value;
  }
}
