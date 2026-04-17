# Changelog

## 0.1.2

### Bug Fixes
- Fixed feature detection for layer-first projects where features sit directly under `lib/ui/` or `lib/presentation/` without an intermediate `pages/`, `features/`, or `screens/` container. Previously these projects were detected as having 0–2 features and always fell back to single-file output; they now produce proper multi-skill splits.

## 0.1.1

### Documentation
- Added `example/README.md` with end-to-end CLI usage scenarios covering analyze, multi-target sync, watch mode, project scaffolding, API key config, and git hooks.
- Documented the implicit `FormatWriter` default constructor so 100% of the public API is covered by dartdoc.

## 0.1.0

Initial release.

### Static Analysis
- **PubspecAnalyzer** — parses `pubspec.yaml` for dependencies, SDK constraints, and package metadata.
- **StructureAnalyzer** — detects folder organization (feature-first, layer-first, hybrid), monorepo structure, and project complexity.
- **PatternDetector** — identifies architecture patterns (Clean Architecture, MVVM, MVC), state management (BLoC, Riverpod, Provider, GetX, MobX, Cubit), navigation, DI, networking, storage, code generation, and internationalization.
- **CodeSampler** — extracts representative code samples (widgets, BLoC/state classes, repositories, models, route configs, DI setup) with context-aware classification.
- **DomainAnalyzer** — scans individual feature directories to produce domain-scoped analysis (state classes, entities, layer breakdown, code samples).
- **ProjectScanner** — orchestrates all analyzers into a unified `ProjectFacts` model.
- **FactsWriter** — writes `.skill_facts.json` with full project analysis data.

### AI-Powered Generation
- **ClaudeClient** — HTTP client for the Claude Messages API.
- **PromptBuilder** — constructs system and user prompts for core, domain, and single-file skill generation.
- **SkillGenerator** — generates skill content via Claude API with automatic template fallback when no API key is configured.
- **TemplateGenerator** — produces skill files from raw facts without an API call (core, domain, and single-file modes).
- **ManifestGenerator** — writes `.skill_manifest.yaml` with machine-readable project metadata.

### Multi-File Skill Splitting
- **SplitPlanner** — decides whether to generate a single skill file or split into core + domain files based on project complexity.
- **DomainFacts model** — domain-scoped analysis data (files, samples, layers, state classes, entities) for per-feature skill generation.
- Auto-detection based on project complexity; controllable via `--split` / `--no-split` flags.
- Formats that support multi-file write separate files per skill; formats that support concatenation join skills with section separators; others receive core-only output.

### Model Selection
- Choose between Claude Sonnet (default) and Claude Opus via `--model` flag or global config.
- Supports shortcut aliases (`sonnet`, `opus`) and full model IDs.
- Priority chain: CLI flag > global config > built-in default (Sonnet).

### CLI Commands
- **`analyze`** — scan a project and generate `.skill_facts.json`, `SKILL.md`, and `.skill_manifest.yaml`. Supports `--split`, `--facts-only`, `--model`, `--output`, and `--verbose`.
- **`sync`** — re-analyze and regenerate all skill files with change detection to skip unnecessary regeneration. Supports `--force`, `--ci`, `--split`, and `--model`.
- **`watch`** — monitor `lib/` and `pubspec.yaml` for changes and regenerate skill files automatically with configurable debounce. Supports `--debounce` and `--model`.
- **`init`** — scaffold a new project from a built-in template (`clean_bloc`, `clean_riverpod`) or clone a GitHub repository, then generate skill files. Supports `--arch`, `--from-repo`, `--name`, `--output`, and `--model`.
- **`config`** — manage global config (API key, model) and project config (output targets, `.skillrc.yaml`). Supports `--set-key`, `--set-model`, `--remove-key`, `--init-skillrc`, `--add-target`, `--remove-target`, and `--show`.
- **`hooks`** — install/remove pre-commit and post-merge git hooks, generate GitHub Actions workflow. Supports `--install`, `--remove`, `--github-action`, `--dart-only`, and `--status`.

### Output Targets
- 8 output formats: `generic` (SKILL.md), `claude_code` (CLAUDE.md), `cursor` (.cursorrules), `copilot` (.github/copilot-instructions.md), `windsurf` (.windsurfrules), `antigravity` (.agents/skills/\<name\>/SKILL.md), `antigravity_rules` (.gemini/GEMINI.md), `agents_md` (AGENTS.md).
- Multi-target support via `.skillrc.yaml` — write to multiple AI tools simultaneously.
- **TargetWriter** dispatches to format-specific writers with multi-file, concatenation, and core-only strategies.

### Configuration
- **Global config** at `~/.flutter_skill_gen/config.yaml` for API key and model preference.
- **Project config** at `.skillrc.yaml` for output targets and watch settings.
- Environment variable support (`FLUTTER_SKILL_API_KEY`).

### CI & Automation
- **GitHooksInstaller** — pre-commit and post-merge hooks that run `flutter_skill_gen sync`.
- **GitHubActionGenerator** — generates `.github/workflows/skill_sync.yml` with Flutter or Dart-only SDK setup.

### VS Code Extension
- Command palette integration (Analyze, Sync, Watch, Preview).
- Status bar indicator (idle, syncing, watching, error).
- Skill file preview in markdown.
- Git hooks and GitHub Action generation from the editor.
