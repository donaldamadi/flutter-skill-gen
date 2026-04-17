# flutter_skill_gen

[![Pub Version](https://img.shields.io/pub/v/flutter_skill_gen.svg)](https://pub.dev/packages/flutter_skill_gen)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Dart](https://img.shields.io/badge/Dart-%5E3.8.0-blue)](https://dart.dev)

A CLI tool that automatically generates **SKILL.md** files for Flutter projects, giving AI coding assistants full project context from the first prompt.

## The Problem

AI coding assistants start every Flutter project blind. They don't know your architecture, state management, folder conventions, or how your features are organized. You waste the first several prompts re-teaching the assistant what your project looks like:

> "We use Clean Architecture with BLoC — or is it Riverpod? Features live under lib/features/ with data, domain, and presentation layers. We use freezed for data classes, go_router for navigation, and dio for networking..."

This repeats for every new conversation, every new team member onboarding with AI tools, and every time context resets.

## The Solution

**flutter_skill_gen** scans your Flutter project and generates a structured skill file — following the [Agent Skills specification](https://agentskills.io/specification) — that AI assistants can read immediately. It detects:

- **Architecture patterns** — Clean Architecture, MVVM, MVC, layer-first, feature-first
- **State management** — BLoC, Riverpod, Provider, GetX, MobX, Cubit, and more
- **Folder structure** — feature organization, layer hierarchy, monorepo detection
- **Dependencies** — navigation, DI, networking, storage, testing, and code generation
- **Complexity** — file counts, feature counts, estimated project magnitude
- **Code patterns** — representative samples from your actual codebase

The generated skill file is written in the format your AI assistant expects, so it has full project context from the very first prompt.

**For existing projects**, flutter_skill_gen detects and documents *what your project already uses* — whether that's BLoC, Riverpod, Provider, GetX, MobX, or any other approach. It never imposes a different architecture or state management style.

**For new projects**, you can scaffold from built-in templates:
- **Clean Architecture + BLoC** (`--arch clean_bloc`)
- **Clean Architecture + Riverpod** (`--arch clean_riverpod`)

Or clone any GitHub repository as a starting point with `--from-repo`.

## Features

- **Automatic project analysis** — scans `pubspec.yaml`, `lib/` structure, and Dart source files
- **8 output formats** — supports Claude Code, Cursor, GitHub Copilot, Windsurf, Antigravity, and more
- **Multi-file skill splitting** — automatically splits large projects into core + domain-specific skill files
- **Watch mode** — regenerates skill files on every file change with configurable debounce
- **Project scaffolding** — create new Flutter projects from built-in Clean Architecture templates
- **Git hooks & CI** — install pre-commit hooks and generate GitHub Actions workflows
- **AI-powered generation** — optionally uses Claude API for richer, more contextual skill files
- **Model selection** — choose between Claude Sonnet and Opus for AI generation
- **Agent Skills spec** — generated files include [spec-compliant](https://agentskills.io/specification) YAML frontmatter, compatible with the `skills` ecosystem

## Installation

### Global activation (recommended)

```bash
dart pub global activate flutter_skill_gen
```

This makes the `flutter_skill_gen` command available system-wide.

### As a dev dependency

Add it to your `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_skill_gen: ^0.1.0
```

Then run:

```bash
dart pub get
```

And use it via:

```bash
dart run flutter_skill_gen <command>
```

## Quick Start

```bash
# 1. Set your Claude API key (optional — enables AI-powered generation)
flutter_skill_gen config --set-key sk-ant-xxxxx

# 2. Analyze your project
flutter_skill_gen analyze

# 3. That's it — SKILL.md is ready for your AI assistant
```

## Configuration

flutter_skill_gen uses two configuration layers:

### Global config (`~/.flutter_skill_gen/config.yaml`)

Stores your API key and default model preference.

```bash
# Set your Claude API key
flutter_skill_gen config --set-key sk-ant-xxxxx

# Set default model (sonnet or opus)
flutter_skill_gen config --set-model opus

# View current configuration
flutter_skill_gen config --show
```

You can also set the API key via environment variable:

```bash
export FLUTTER_SKILL_API_KEY=sk-ant-xxxxx
```

The environment variable takes priority over the config file.

### Project config (`.skillrc.yaml`)

Controls output targets and watch settings per project.

```bash
# Create a default .skillrc.yaml
flutter_skill_gen config --init-skillrc

# Add output targets
flutter_skill_gen config --add-target claude_code
flutter_skill_gen config --add-target cursor

# Remove an output target
flutter_skill_gen config --remove-target generic
```

Example `.skillrc.yaml`:

```yaml
output_targets:
  - format: claude_code
  - format: cursor
  - format: copilot

watch:
  enabled: true
  debounce_ms: 500
```

## Commands

### `analyze`

Scans a Flutter project and generates skill files with full project context.

```bash
# Analyze the current directory
flutter_skill_gen analyze

# Analyze a specific project
flutter_skill_gen analyze --path /path/to/project

# Output to a different directory
flutter_skill_gen analyze --path ./my_app --output ./docs

# Only generate the facts file (skip SKILL.md)
flutter_skill_gen analyze --facts-only

# Force split into core + domain skill files
flutter_skill_gen analyze --split

# Force single file even for large projects
flutter_skill_gen analyze --no-split

# Use Claude Opus for higher quality generation
flutter_skill_gen analyze --model opus

# Enable verbose logging
flutter_skill_gen analyze --verbose
```

**Generated files:**

| File | Description |
|---|---|
| `.skill_facts.json` | Raw project analysis data (architecture, dependencies, patterns) |
| `SKILL.md` | The skill file your AI assistant reads (format depends on output targets) |
| `.skill_manifest.yaml` | Machine-readable manifest of detected facts |

**Split mode output (for large projects):**

When split mode is active (auto-detected or via `--split`), the tool generates:

- A **core skill file** covering project-wide architecture, conventions, and dependencies
- **Domain skill files** for each detected feature/domain (e.g., `auth`, `payments`, `profile`)

This keeps each file focused and prevents AI assistants from being overwhelmed by a single massive context file.

### `sync`

Re-analyzes the project and regenerates all skill files. Includes change detection to skip unnecessary regeneration.

```bash
# Sync skill files for the current project
flutter_skill_gen sync

# Force regeneration even if nothing changed
flutter_skill_gen sync --force

# CI mode (exit code 1 on analysis failure)
flutter_skill_gen sync --ci

# Sync with split mode and a specific model
flutter_skill_gen sync --split --model opus
```

`sync` compares the new analysis against the existing `.skill_facts.json`. If nothing meaningful has changed (ignoring timestamps), it skips regeneration to save API calls. Use `--force` to override this behavior.

### `watch`

Watches for file changes and automatically regenerates skill files with debounce.

```bash
# Watch the current project
flutter_skill_gen watch

# Watch a specific project
flutter_skill_gen watch --path /path/to/project

# Custom debounce interval (milliseconds)
flutter_skill_gen watch --debounce 1000

# Watch with a specific model
flutter_skill_gen watch --model opus
```

The watcher monitors `lib/` for `.dart` file changes (excluding generated files like `.g.dart` and `.freezed.dart`) and `pubspec.yaml`. On each change, it re-scans the project and regenerates all skill files after the debounce interval.

### `init`

Scaffolds a new Flutter project from a built-in template or a GitHub repository, then generates skill files.

```bash
# Scaffold from a built-in template
flutter_skill_gen init --arch clean_bloc
flutter_skill_gen init --arch clean_riverpod

# Scaffold with a custom project name
flutter_skill_gen init --arch clean_bloc --name my_app

# Scaffold into a specific directory
flutter_skill_gen init --arch clean_bloc --output ./projects/my_app

# Clone and analyze a GitHub repository
flutter_skill_gen init --from-repo https://github.com/user/flutter_project

# Use a specific model for skill generation
flutter_skill_gen init --arch clean_bloc --model opus
```

**Built-in templates:**

| Template | Description |
|---|---|
| `clean_bloc` | Clean Architecture with BLoC state management |
| `clean_riverpod` | Clean Architecture with Riverpod state management |

When using `--from-repo`, the tool clones the repository (shallow, depth 1), removes the `.git` directory so you start fresh, then analyzes and generates skill files.

### `config`

Manages global and project-level configuration.

```bash
# Set Claude API key
flutter_skill_gen config --set-key sk-ant-xxxxx

# Set default Claude model
flutter_skill_gen config --set-model opus

# Remove stored API key
flutter_skill_gen config --remove-key

# Initialize .skillrc.yaml with defaults
flutter_skill_gen config --init-skillrc

# Add an output target to .skillrc.yaml
flutter_skill_gen config --add-target claude_code

# Remove an output target
flutter_skill_gen config --remove-target generic

# Show all configuration
flutter_skill_gen config --show
```

### `hooks`

Manages git hooks and CI integration for automated skill synchronization.

```bash
# Install pre-commit and post-merge git hooks
flutter_skill_gen hooks --install

# Remove flutter_skill_gen git hooks
flutter_skill_gen hooks --remove

# Generate a GitHub Actions workflow
flutter_skill_gen hooks --github-action

# Generate workflow for Dart-only projects (no Flutter SDK)
flutter_skill_gen hooks --github-action --dart-only

# Check which hooks are installed
flutter_skill_gen hooks --status
```

**What each hook does:**

- **`pre-commit`** — before every commit, checks if any files in `lib/`, `pubspec.yaml`, or `test/` are staged. If so, it runs `flutter_skill_gen sync --ci` to regenerate skill files and automatically stages the updated outputs (`.md`, `.cursorrules`, `.windsurfrules`, etc.) so they're included in the same commit. If sync fails, the commit still proceeds — it's non-blocking.
- **`post-merge`** — after every `git merge` or `git pull`, regenerates skill files to reflect the newly merged code.

**Safety:** if you already have existing git hooks, they're backed up (e.g., `pre-commit.backup`) before being replaced. Removing flutter_skill_gen hooks restores any backups automatically. Only hooks marked as `Auto-generated by flutter_skill_gen` are ever modified or removed.

The GitHub Actions workflow runs skill sync on push to `main`, ensuring skill files stay current in CI. Add `FLUTTER_SKILL_API_KEY` as a repository secret to enable AI-powered generation in CI.

## Output Formats

Configure output targets in `.skillrc.yaml` to write skill files in the format your AI assistant expects.

| Format | Output Path | Description |
|---|---|---|
| `generic` | `SKILL.md` | Universal format, works with any tool |
| `claude_code` | `CLAUDE.md` | Optimized for Claude Code |
| `cursor` | `.cursorrules` | Cursor AI rules file |
| `copilot` | `.github/copilot-instructions.md` | GitHub Copilot instructions |
| `windsurf` | `.windsurfrules` | Windsurf rules file |
| `antigravity` | `.agents/skills/<name>/SKILL.md` | Antigravity multi-file skills |
| `antigravity_rules` | `.gemini/GEMINI.md` | Antigravity project-level rules |
| `agents_md` | `AGENTS.md` | AGENTS.md standard format |

You can configure multiple targets simultaneously. For example, if your team uses both Claude Code and Cursor:

```yaml
output_targets:
  - format: claude_code
  - format: cursor
```

## Agent Skills Specification

flutter_skill_gen generates skill files that follow the [Agent Skills specification](https://agentskills.io/specification). Every generated `SKILL.md` includes spec-compliant YAML frontmatter:

```markdown
---
name: my-app-core
description: Core architecture, conventions, and dependencies for my_app.
---

# my_app

## Project Overview
...
```

This means flutter_skill_gen's output is compatible with the growing Agent Skills ecosystem, including the [`skills`](https://pub.dev/packages/skills) CLI by Serverpod.

### Shipping skills with your package

If you're a package author, you can use flutter_skill_gen to auto-generate skills and then ship them in your published package:

1. Run `flutter_skill_gen analyze` to generate skill files
2. Place the generated output in a `skills/` directory at your package root
3. Users install them with `skills get` — your AI-generated context flows into their IDE automatically

flutter_skill_gen is the **authoring tool** — it generates the skills. Distribution tools like the `skills` CLI handle installation into IDEs.

## Model Selection

flutter_skill_gen supports Claude model selection for AI-powered generation.

```bash
# Use Claude Sonnet (default — fast and cost-effective)
flutter_skill_gen analyze --model sonnet

# Use Claude Opus (more detailed and nuanced output)
flutter_skill_gen analyze --model opus

# Pass a full model ID
flutter_skill_gen analyze --model claude-sonnet-4-20250514

# Set a default model globally
flutter_skill_gen config --set-model opus
```

**Model priority chain:**

1. `--model` CLI flag (highest priority)
2. Global config (`~/.flutter_skill_gen/config.yaml`)
3. Built-in default: Claude Sonnet

If no API key is configured, flutter_skill_gen falls back to a template-based generator that produces skill files without an API call.

## What Gets Detected

flutter_skill_gen performs deep analysis of your Flutter project:

| Category | Examples |
|---|---|
| **Architecture** | Clean Architecture, MVVM, MVC, layer-first, feature-first |
| **State Management** | BLoC, Cubit, Riverpod, Provider, GetX, MobX, Redux, ValueNotifier |
| **Navigation** | go_router, auto_route, Navigator 2.0, beamer |
| **Dependency Injection** | injectable, get_it, riverpod, provider |
| **Networking** | dio, http, chopper, retrofit, graphql |
| **Storage** | hive, shared_preferences, sqflite, drift, isar, objectbox |
| **Code Generation** | freezed, json_serializable, build_runner |
| **Testing** | bloc_test, mockito, mocktail, integration_test |
| **Internationalization** | flutter_intl, gen_l10n, easy_localization, ARB files |
| **Project Structure** | Feature directories, layer hierarchy, monorepo detection |
| **Complexity** | File counts, feature counts, estimated magnitude |

## How It Works

1. **Static Scanner** reads the project and extracts structured facts into `.skill_facts.json`
2. **AI Synthesis** (optional) prompts Claude to generate rich, human-readable skill content
3. **Template Fallback** produces skill files from raw facts when no API key is available
4. **Split Planner** determines whether to generate a single skill file or split into core + domain files based on project complexity
5. **Target Writer** writes to every configured AI tool's native format simultaneously

## Example Output

Running `flutter_skill_gen analyze` on a medium-sized Clean Architecture project:

```
Analyzing Flutter project at: /path/to/my_app
Generated .skill_facts.json
Generated .skill_manifest.yaml
Split mode: generating 4 skill files...
Wrote to 2 output target(s)

Project: my_app
Architecture: clean_architecture
State Management: bloc
Organization: feature-first
Complexity: medium (42 files, 5 features)
Mode: split (core + domain skills)
```

## VS Code Extension

A companion VS Code extension is available in the `extension/` directory with:

- Command palette integration (Analyze, Sync, Watch, Preview)
- Status bar indicator (idle, syncing, watching, error)
- Skill file preview (opens SKILL.md in markdown preview)
- Git hooks and GitHub Action generation

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the [repository](https://github.com/donaldamadi/flutter_skill_gen)
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Run the tests (`dart test`)
4. Run the analyzer (`dart analyze`)
5. Commit your changes
6. Push to the branch
7. Open a Pull Request

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
