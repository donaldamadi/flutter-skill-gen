# Changelog

## 0.4.0

### Claude Code Best-Practice Alignment

Generated skills now follow the patterns the Claude Code team has published for agentic engineering — lazy-loading, tight line budgets, gotchas, and data-flow diagrams. All changes are additive on the output side; existing AI and template paths still produce valid SKILL.md files.

- **`paths:` frontmatter for lazy loading.** Every generated `SKILL.md` / `SKILL_<feature>.md` / `CLAUDE_<feature>.md` now emits a `paths:` YAML block so Claude Code only loads a skill when a file matching one of its globs is touched. The core skill is scoped to `pubspec.yaml`, `lib/main.dart`, and any `lib/core/`, `lib/shared/`, `lib/common/`, `lib/config/`, or `lib/app/` tree that actually exists; in single-file mode it also gets `lib/**/*.dart`. Per-feature skills get `lib/<feature-path>/**/*.dart` derived from the evidence bundle.
- **Per-skill line budget.** All three system prompts (single, core, domain) now carry a hard line ceiling (180 / 150 / 120 lines respectively, with lower aim targets) replacing the old word budgets. `DraftVerifier` gained a new `ViolationKind.overLineBudget` that flags drafts over 200 lines — Claude Code's published degradation threshold. The new check is draft-level rather than line-scoped, so `annotate` / `strip` modes don't munge the file; the signal surfaces via the verifier warning log.
- **Deterministic Gotchas + Data Flow sections.** Two new trusted-source modules, `GotchasLibrary` and `AsciiDiagrams`, emit a `## Gotchas` bullet list and a `## Data Flow` ASCII diagram for every skill. Rules are keyed by detected stack (bloc, riverpod, go_router, auto_route, get_it+injectable, freezed+hive pairs, clean-arch missing-layer, feature-first-no-shared, and more) and feature-scoped variants. Because both sections are generated from grounded detection — never from AI output — they bypass the hallucination surface and are spliced onto every draft after verification. The prompts now explicitly tell Claude *not* to write these sections.
- **Description fields are loading triggers, not summaries.** The `description:` YAML field is what Claude Code matches against the current task to decide when to surface a skill. Previous descriptions read like human project summaries (`"Core architecture, conventions, and dependencies for <project>"`); 0.4.0 rewrites them as load-trigger clauses (`"Load when working in the Flutter + clean architecture + bloc app "<project>" — architecture, conventions, and project-specific rules."`). Domain skills get `"Load when editing the <feature> feature (<layers>) in <project>"`.
- **No-boilerplate prompt discipline.** All three prompts now carry an explicit `Do NOT state the obvious` clause — no "this is a Flutter project", no generic BLoC/Riverpod/Clean Architecture primer content, only project-specific rules that would surprise a mid-level Flutter engineer who just cloned the repo.
- **Split threshold lowered.** `_recommendSkillFiles` previously held single-file output up to 50 files / 3 features; with a 200-line skill budget that threshold produced overflow. The cut now sits at 30 files / 2 features, so medium projects split sooner and each file stays lean.

## 0.3.1

### Bug Fixes — Audit-Driven Accuracy

Three issues surfaced by a real-world `tng_laws_ai_mobile` audit against 0.3.0:

- **Feature cap silently dropped beyond the first 5.** `_recommendSkillFiles` was doing `structure.featureDirs.take(5)`, so any project with more than five features had its 6th+ feature quietly omitted from both `recommended_skill_files` and the split plan. Projects like moneypal and tng_laws_ai_mobile were missing `profile`, `onboarding`, `shared`, and `navigation` skills even though the features were correctly detected. The cap is gone — every detected feature now produces a per-feature skill.
- **Dev dependencies were silently dropped.** `PubspecAnalyzer.analyzeDependencies` only routed dev deps into `code_generation` / `testing` buckets and discarded everything else (`flutter_lints`, `flutter_launcher_icons`, `flutter_native_splash`, etc.), so generated skill files had no signal that a project was, for instance, using stock Flutter lints. `DependencyInfo` now carries a new `dev_dependencies` list (exposed in `.skill_facts.json` as `dev_dependencies`) that preserves every dev dep minus `flutter` / `flutter_localizations`.
- **Stock `flutter create` widget test was counted as real coverage.** `_analyzeTests` flagged `hasWidgetTests=true` whenever any file contained `testWidgets(` or `pumpWidget(` — including the untouched `test/widget_test.dart` counter-increment stub that ships with `flutter create`. The scanner now recognizes the stock template (references `MyApp(`, taps `Icons.add`, asserts the `'0'` → `'1'` transition) and excludes it from the widget-test signal.

## 0.3.0

### Bug Fixes — Multi-File Output & Per-Feature Evidence

Two regressions surfaced by a real-world audit of a complex Riverpod app using this package:

- **Per-feature evidence was empty in layer-first projects.** `feature_evidence[].file_count` was `0` under every feature in `.skill_facts.json` when features sat directly under `lib/ui/<feature>` (or `lib/presentation/<feature>`) with no intermediate `pages/`, `features/`, or `screens/` container. Root cause: `DomainAnalyzer._findDomainDirectory` was missing the direct-layer-container tier that `StructureAnalyzer._findFeatureDir` gained in 0.1.2. `ProjectScanner` now threads the already-resolved feature path from `StructureAnalyzer.analyzeFeatureBreakdown` into `DomainAnalyzer.analyze(..., resolvedPath: ...)`, and the analyzer's own lookup also mirrors the structure analyzer's full priority order as belt-and-suspenders.
- **Split mode generated one concatenated SKILL.md, not per-feature files.** The default `generic` and `claude_code` writers had `supportsMultiFile=false`, so `TargetWriter.writeMultiSkill` concatenated every skill into a single file while `ManifestGenerator` simultaneously promised `SKILL_<feature>.md` siblings that never landed on disk. Both writers now `supportsMultiFile=true` and produce `SKILL_<feature>.md` / `CLAUDE_<feature>.md` siblings at the project root — matching the layout the manifest already advertises.
- **Forced split now expands to every detected feature.** `SplitPlanner.plan(..., forceSplit: true)` previously only iterated `recommendedSkillFiles` (which caps at 5 features and skips the "core-only" threshold). Explicit `--split` now unions in `structure.featureDirs` so small-but-multi-feature projects produce one skill per feature as expected.
- **Manifest is grounded in the plan.** `ManifestGenerator.write(..., plan: plan)` (wired into `analyze`, `sync`, and `watch`) references only the skill files the plan will actually produce, eliminating the phantom `SKILL_data.md`-style entries when a recommended domain turns out to have no `lib/` directory.

Regression tests in `test/regression/multi_file_and_evidence_test.dart` lock in both fixes, and a new `sample_layer_first_project` fixture exercises the moneypal-style `lib/ui/<feature>` pattern end-to-end.

## 0.2.1

### Model Defaults
- Bumped the built-in default model from `claude-sonnet-4-20250514` to `claude-sonnet-4-6` (Sonnet 4.6), and refreshed the `opus` alias target to `claude-opus-4-7` (Opus 4.7). The alias map and `defaultModel` are now consistent — `--model sonnet`, an unset global config, and a missing `--model` flag all resolve to the same model. Users with `claude-sonnet-4-20250514` pinned in their `~/.flutter_skill_gen/config.yaml` continue to call that exact model (unmapped IDs pass through unchanged).

## 0.2.0

### Hallucination-Proof Generation
- **EvidenceBundle** — new ground-truth payload emitted by `ProjectScanner` that enumerates every `lib/` file path, every declared class name, per-feature layer/state/widget evidence, known file-name glob patterns, and DI registration style (`centralized` vs `per-feature`). Serialized into `.skill_facts.json` and spliced into every Claude prompt.
- **Grounding rules** — every system prompt (single, core, domain) now carries a `CRITICAL — grounding rules` block instructing the model to draw class names, file paths, globs, and DI claims exclusively from `evidence.*` fields. Available as `PromptBuilder.groundingRules` for reuse.
- **DraftVerifier** — post-generation pass that cross-checks AI drafts against the evidence bundle. Flags four violation kinds: `unknownFilePath`, `unknownClassName`, `unknownGlobPattern`, and `falseDiPerFeatureClaim`. Configurable via `VerifierMode.annotate` (default — inline `<!-- [UNVERIFIED: …] -->` markers), `VerifierMode.strip` (delete offending lines), or `VerifierMode.fatal` (raise `DraftVerificationFailedException`).
- **Env-var configuration** — the `FLUTTER_SKILL_VERIFIER_MODE` environment variable selects the verifier mode globally (`annotate` | `strip` | `fatal`; case-insensitive; unknown values fall back to `annotate`). An explicit `verifierMode` constructor argument overrides the env var.
- Domain-scoped prompts now include a trimmed evidence slice containing the relevant `feature_evidence` entry plus project-wide DI and file manifest — keeps per-feature drafts grounded without bloating the prompt.

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
