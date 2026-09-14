import 'dart:io';

import 'package:path/path.dart' as p;

/// Where an agent looks for installed skills.
///
/// Every agent reads the open Agent Skills format, but each looks in
/// its own directory. `.agents/skills/` is the shared location Codex,
/// Gemini CLI, and OpenCode all read; Claude Code reads
/// `.claude/skills/`.
enum SkillLocation {
  /// `.claude/skills/` — read by Claude Code and OpenCode.
  claude('claude', '.claude'),

  /// `.agents/skills/` — read by Codex, Gemini CLI, and OpenCode.
  agents('agents', '.agents');

  const SkillLocation(this.id, this.dirName);

  /// Stable identifier used on the CLI.
  final String id;

  /// Directory this location lives under, relative to a project root
  /// or home directory.
  final String dirName;

  /// The locations installed when the user names no agent.
  ///
  /// Both, because one command should leave the skill discoverable by
  /// every agent that implements the standard.
  static const defaults = [claude, agents];

  /// Resolves an `--agent` value to the locations it needs.
  ///
  /// Returns `null` when [input] names no known agent.
  static List<SkillLocation>? tryParse(String input) {
    return switch (input.trim().toLowerCase()) {
      'all' => defaults,
      'claude' || 'claude-code' || 'claude_code' => [claude],
      'codex' => [agents],
      'gemini' || 'gemini-cli' || 'gemini_cli' => [agents],
      // OpenCode reads both; the shared directory is enough.
      'opencode' => [agents],
      'agents' || 'cursor' => [agents],
      _ => null,
    };
  }

  /// Agent names accepted by `--agent`, for help text.
  static const accepted = [
    'all',
    'claude',
    'codex',
    'gemini',
    'opencode',
    'agents',
  ];
}

/// The Agent Skill that teaches a coding agent to drive this CLI.
///
/// The content is embedded as a string rather than shipped as a data
/// file because `dart pub global activate` gives an activated package
/// no reliable path to its own assets — a compiled snapshot has no
/// package root to resolve against.
abstract final class AgentSkillAsset {
  /// Directory name the skill is installed under.
  static const skillName = 'flutter-skill-gen';

  /// Returns the install directory for a project-local skill.
  static String projectDir(
    String projectPath, {
    SkillLocation location = SkillLocation.claude,
  }) => p.join(projectPath, location.dirName, 'skills', skillName);

  /// Returns the install directory for a user-wide skill.
  static String globalDir({
    SkillLocation location = SkillLocation.claude,
    Map<String, String>? environment,
  }) {
    final env = environment ?? Platform.environment;
    final home = env['HOME'] ?? env['USERPROFILE'] ?? '.';
    return p.join(home, location.dirName, 'skills', skillName);
  }

  /// Writes `SKILL.md` into [directory] and returns its path.
  static String install(String directory) {
    final path = p.join(directory, 'SKILL.md');
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
    return path;
  }

  /// The full `SKILL.md` body, frontmatter included.
  static const content = '''---
name: flutter-skill-gen
description: >-
  Generate or refresh the project-context skill files for a Flutter or
  Dart repo, so AI assistants know its architecture, state management,
  conventions and gotchas from the first prompt. Use when asked to
  create, update, refresh or maintain a repo overview, a project
  context doc, SKILL.md, AGENTS.md, CLAUDE.md context, .cursorrules or
  Copilot instructions inside a Flutter project.
---

# Writing Flutter project skill files

`flutter_skill_gen` scans a Flutter project and hands you a grounded
picture of it. The split of labour is fixed: **the CLI does the
analysis, you write the prose, the CLI assembles and checks it.**

Do not write SKILL.md by hand, and do not skip the CLI. The scan
produces an evidence bundle — every file path and class name under
`lib/`, per-feature layer inventories, real DI wiring — and the
`assemble` step verifies your writing against it. A path or class you
assert that the evidence does not contain gets stripped or flagged as
unverified, which is exactly what stops a plausible-sounding overview
from being wrong.

## Workflow

### 1. Check the CLI

```bash
flutter_skill_gen --help
```

Look for `prompt` and `assemble` in the list of available commands.

- **Command not found**, or **`prompt` is missing from the list** (an
  install older than 1.1.0): install or upgrade, then check again.

  ```bash
  dart pub global activate flutter_skill_gen
  ```

- **The project lists `flutter_skill_gen` under `dev_dependencies`**
  and the global command is unavailable: prefix every command in this
  skill with `dart run`, for example `dart run flutter_skill_gen prompt`.

If `dart` itself is missing, stop and tell the user — this skill
cannot do anything useful without the analyzer.

### 2. Emit the prompts

From the project root:

```bash
flutter_skill_gen prompt
```

This scans the project and writes a `.skill_work/` directory:

| Path | What it holds |
| --- | --- |
| `.skill_work/plan.json` | The scopes to write, in order |
| `.skill_work/prompts/<scope>.md` | Instructions + facts for one scope |
| `.skill_work/drafts/` | Empty — you write here |

Large projects are split into a `core` scope plus one scope per
feature; small ones get a single `core` scope. Pass `--split` or
`--no-split` to force the decision, and `--path <dir>` to analyse a
project other than the current directory.

### 3. Write one draft per scope

Read `.skill_work/plan.json` for the scope list. Then, for each scope:

1. Read `.skill_work/prompts/<scope>.md` **in full**. The top half is
   the spec your draft must satisfy; the bottom half is the project
   JSON, including an `evidence` block.
2. Write your draft to `.skill_work/drafts/<scope>.md`.

The prompt file is authoritative, but these are the rules people get
wrong most often:

- **No YAML frontmatter and no wrapping code fences.** Both are added
  or stripped for you; writing them yourself corrupts the output.
- **No "Gotchas" or "Data Flow" section.** Those are generated
  deterministically and appended afterwards. Writing your own creates
  duplicates.
- **Respect the line budget** named in the prompt: under 180 lines for
  a single-file skill, under 150 for a core skill in split mode, under
  120 for a feature skill. Aim well below each cap. Cut prose before
  you cut facts.
- **Only name paths, classes and file-name globs that appear in the
  `evidence` block.** If you want to reference something that is not
  there, describe the pattern abstractly instead.
- **Skip what is obvious.** No explanation of what BLoC or Clean
  Architecture is. Keep only what would surprise an experienced
  Flutter engineer who just cloned this repo.

You may read the project's own source files to write a better draft —
you have the repo in front of you, which the API path does not — but
the evidence block still bounds what you are allowed to assert.

### 4. Assemble

```bash
flutter_skill_gen assemble
```

This verifies every draft, splices in the generated diagrams and
gotchas, adds frontmatter, and writes the files to every output target
configured in `.skillrc.yaml` (Claude Code, Cursor, Copilot, Windsurf,
AGENTS.md, and so on).

If it reports violations, they name the exact claim and line. Fix the
draft — usually by removing an invented path or class, or rephrasing
it abstractly — and run `assemble` again. Do not edit the assembled
output to silence a violation; the next run would overwrite it.

To fail the run on any unsupported claim rather than annotating it:

```bash
FLUTTER_SKILL_VERIFIER_MODE=fatal flutter_skill_gen assemble
```

### 5. Clean up

```bash
flutter_skill_gen assemble --clean
```

`--clean` removes `.skill_work/` once the run succeeds. Add
`.skill_work/` to `.gitignore` if the user wants to keep it around
between runs.

## Maintaining an existing skill file

Re-run the same four steps. `prompt` always rescans, so the drafts you
write reflect the project as it is now.

When the change is small and you can see what moved (a renamed
feature, a swapped dependency), it is fine to start from the existing
assembled file, edit it down into `.skill_work/drafts/<scope>.md` —
minus its frontmatter and its generated Gotchas and Data Flow
sections — and let `assemble` re-verify it. That keeps the prose
stable across runs instead of rewriting it from scratch each time.

## When not to use this skill

- The project is not Flutter or Dart — there is no `pubspec.yaml`.
  This CLI has nothing to say about it.
- The user wants the one-shot path instead: `flutter_skill_gen analyze`
  with a configured API key, or with `--provider claude-code`, `codex`,
  or `gemini-cli` to drive a locally installed agent CLI without a key.
  Those generate the same files without your involvement.
''';
}
