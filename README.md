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
- **AI-powered generation** — optionally uses an LLM API for richer, more contextual skill files
- **Multi-provider** — Anthropic, any OpenAI-compatible endpoint (OpenAI, DeepSeek, Groq, Together, OpenRouter, Ollama, vLLM), or Google Gemini
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
# 1. Analyze your project
flutter_skill_gen analyze

# 2. That's it — SKILL.md is ready for your AI assistant
```

That works with no setup at all. To get richer, AI-written skill files, add an
API key — see [AI Providers](#ai-providers):

```bash
flutter_skill_gen config --set-key sk-ant-xxxxx
flutter_skill_gen analyze
```

## Configuration

flutter_skill_gen uses two configuration layers:

### Global config (`~/.flutter_skill_gen/config.yaml`)

Your AI provider, API keys, and default model — shared across every project.

```bash
# View current configuration
flutter_skill_gen config --show
```

See [AI Providers](#ai-providers) for what goes in here and how to set it.

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

## AI Providers

Skill generation works with or without an AI provider. **Without a key** the tool
builds skill files from the facts it scanned — no setup, no cost. **With a key**
it also asks a model to write richer prose around those facts.

Three providers are supported:

| `--provider` | Service | Get a key from | Environment variable |
| --- | --- | --- | --- |
| `anthropic` *(default)* | Claude | [console.anthropic.com](https://console.anthropic.com/settings/keys) | `ANTHROPIC_API_KEY` |
| `openai` | OpenAI + compatible services | [platform.openai.com](https://platform.openai.com/api-keys) | `OPENAI_API_KEY` |
| `gemini` | Google Gemini | [aistudio.google.com](https://aistudio.google.com/apikey) | `GEMINI_API_KEY` |

Keys are **not interchangeable** — each one only works with the service that
issued it. An OpenAI key sent to Anthropic returns a `401`.

### Setting up

Pass `--set-provider` and `--set-key` together so the key is stored against the
right provider:

```bash
flutter_skill_gen config --set-provider anthropic --set-key sk-ant-xxxxx
flutter_skill_gen analyze
```

Keys are kept **per provider**, so adding a second one never overwrites the
first:

```yaml
# ~/.flutter_skill_gen/config.yaml
provider: anthropic
model: claude-sonnet-5
api_keys:
  anthropic: sk-ant-xxxxx
  openai: sk-proj-xxxxx
```

Switching between providers you have already set up needs no key:

```bash
flutter_skill_gen config --set-provider openai
```

Check what is active at any time with `flutter_skill_gen config --show`. The
`api_key` line shows the key that will actually be used.

### Using OpenAI-compatible services

`--provider openai` works with any service that speaks OpenAI's API shape. Point
it at one with `--base-url`:

```bash
# DeepSeek
flutter_skill_gen analyze \
  --provider openai \
  --base-url https://api.deepseek.com/v1 \
  --model deepseek-chat

# A local Ollama server (the key is unused, but must be set to something)
flutter_skill_gen analyze \
  --provider openai \
  --base-url http://localhost:11434/v1 \
  --model qwen2.5-coder
```

Common base URLs:

| Service | Base URL |
| --- | --- |
| OpenAI | *(default — omit `--base-url`)* |
| DeepSeek | `https://api.deepseek.com/v1` |
| Groq | `https://api.groq.com/openai/v1` |
| Together | `https://api.together.xyz/v1` |
| OpenRouter | `https://openrouter.ai/api/v1` |
| Ollama (local) | `http://localhost:11434/v1` |

These all share the one `openai` key slot, so storing a DeepSeek key replaces a
stored OpenAI key. If you switch between two of them often, keep one in
`OPENAI_API_KEY` and store the other.

`--provider` accepts aliases so the command reads naturally:
`deepseek`, `groq`, `together`, `fireworks`, `openrouter`, `ollama`, and
`openai-compatible` all mean `openai`; `claude` means `anthropic`; `google` means
`gemini`.

### Choosing a model

```bash
# Claude shortcuts
flutter_skill_gen analyze --model sonnet
flutter_skill_gen analyze --model opus

# Any full model ID
flutter_skill_gen analyze --provider gemini --model gemini-3.8-flash

# Set a default
flutter_skill_gen config --set-model opus
```

Each provider has its own default, used when you don't specify one:

| Provider | Default model |
| --- | --- |
| `anthropic` | `claude-sonnet-5` |
| `openai` | `gpt-5.6-sol` |
| `gemini` | `gemini-3.8-flash` |

Two things worth knowing:

- The `sonnet` and `opus` shortcuts name Claude models, so they only expand under
  `anthropic`. Any other provider receives the value unchanged.
- OpenAI and Google rename and retire model IDs often. Set `--model` explicitly
  for those two rather than relying on the defaults above.

### Where keys are read from

For the active provider, the first of these that is set wins:

1. `FLUTTER_SKILL_API_KEY` — wins for every provider, handy in CI
2. That provider's own variable — `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, or `GEMINI_API_KEY`
3. `api_keys.<provider>` in `~/.flutter_skill_gen/config.yaml`

An already-exported key therefore just works:

```bash
export OPENAI_API_KEY=sk-proj-xxxxx
flutter_skill_gen analyze --provider openai
```

> **Upgrading from an earlier version?** Reading the provider variables in step 2
> is new. If your shell already exports one, the tool will start using it — where
> an unconfigured install used to produce template output, it now makes real,
> billable API calls. Run `config --show` to see which key is active.
>
> Configs using the older single `api_key:` field still work unchanged, as a
> final fallback after the three sources above. Nothing needs migrating.

### When generation fails

A failed API call is never fatal. Any error — wrong key, unknown model, no
network — logs a warning and falls back to template-based output, so you always
get a skill file.

| Message | Usual cause |
| --- | --- |
| `API returned 401` | The key belongs to a different provider, or an environment variable is overriding your stored key. Check `config --show`. |
| `API returned 404` | The model ID isn't valid for this provider. |
| Generated with no API call | No key was found for the active provider. |
| Calls going to the wrong host | A stored `base_url` persists across provider switches. Clear it with `config --set-base-url ""`. |

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

# Use a more capable model for higher quality generation
flutter_skill_gen analyze --model opus

# Enable verbose logging
flutter_skill_gen analyze --verbose
```

**Generated files:**

| File | Description |
| --- | --- |
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
| --- | --- |
| `clean_bloc` | Clean Architecture with BLoC state management |
| `clean_riverpod` | Clean Architecture with Riverpod state management |

When using `--from-repo`, the tool clones the repository (shallow, depth 1), removes the `.git` directory so you start fresh, then analyzes and generates skill files.

### `config`

Manages global and project-level configuration.

```bash
# Set the API key for the active provider
flutter_skill_gen config --set-key sk-ant-xxxxx

# Set default model
flutter_skill_gen config --set-model opus

# Switch provider (anthropic, openai, gemini)
flutter_skill_gen config --set-provider openai

# Point an OpenAI-compatible provider at its own host
flutter_skill_gen config --set-base-url https://api.deepseek.com/v1

# Remove the active provider's stored API key
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
| --- | --- | --- |
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

## What Gets Detected

flutter_skill_gen performs deep analysis of your Flutter project:

| Category | Examples |
| --- | --- |
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
2. **AI Synthesis** (optional) prompts the configured provider to generate rich, human-readable skill content
3. **Template Fallback** produces skill files from raw facts when no API key is available
4. **Split Planner** determines whether to generate a single skill file or split into core + domain files based on project complexity
5. **Target Writer** writes to every configured AI tool's native format simultaneously

## Example Output

Running `flutter_skill_gen analyze` on a medium-sized Clean Architecture project:

```text
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
