# flutter_skill_gen — examples

`flutter_skill_gen` is a command-line tool. The examples below assume you've activated it globally:

```bash
dart pub global activate flutter_skill_gen
```

## 1. Analyze an existing Flutter project

From the root of any Flutter project:

```bash
flutter_skill_gen analyze
```

This scans your project and generates:

- `.skill_facts.json` — structured project facts
- `SKILL.md` — Agent Skills-compliant context file for AI assistants
- `.skill_manifest.yaml` — machine-readable project metadata

## 2. Write to multiple AI tools at once

Create a `.skillrc.yaml` at the project root:

```yaml
targets:
  - generic        # SKILL.md
  - claude_code    # CLAUDE.md
  - cursor         # .cursorrules
  - copilot        # .github/copilot-instructions.md
```

Then run:

```bash
flutter_skill_gen sync
```

## 3. Watch for changes during development

```bash
flutter_skill_gen watch --debounce 2000
```

Regenerates skill files whenever `lib/` or `pubspec.yaml` changes.

## 4. Scaffold a new project from a template

```bash
flutter_skill_gen init my_app --arch clean_bloc
```

Available architectures: `clean_bloc`, `clean_riverpod`.

## 5. Configure your Claude API key (optional)

Without an API key, `flutter_skill_gen` falls back to a deterministic template generator. With a key, it uses Claude to produce richer, more contextual SKILL.md files.

```bash
flutter_skill_gen config --set-key sk-ant-...
flutter_skill_gen config --set-model sonnet
```

## 6. Install git hooks for automatic syncing

```bash
flutter_skill_gen hooks --install
```

This adds pre-commit and post-merge hooks that keep your skill files in sync with your code.

---

See the [main README](../README.md) for the full command reference.
