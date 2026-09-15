# Changelog

## 1.1.0

Two ways to generate skill files without an API key, both answering the
same request: *"I'd prefer to use Claude Code directly."* Neither is
Claude-only: the same paths work with OpenAI Codex, Gemini CLI, and
OpenCode.

### Keyless Generation via a Local Agent CLI

- **Three new providers: `claude-code`, `codex`, and `gemini-cli`.** Each drives a coding agent already installed on the machine instead of calling a hosted API, authenticating with the sign-in that agent already holds. No API key, billed to the existing subscription. Persist one with `config --set-provider <id>`. Aliases: `claude_code`/`claudecode`/`cc`, `codex-cli`, `gemini_cli`/`geminicli`. `gemini-cli` drives the local binary and is deliberately distinct from `gemini`, which calls the paid API.
- **`AgentCli` describes what differs between them** — the flag that turns on non-interactive mode, whether a separate system prompt is accepted, and how the answer comes back — so one `AgentCliClient` drives all three rather than three near-identical clients. Codex and Gemini CLI have no system-prompt flag, so the grounding rules are prepended to the prompt; every agent therefore receives the same instructions the API providers do.
- **Agent-specific hardening.** Claude Code is invoked with its filesystem, shell, and network tools denied; Codex with `--sandbox read-only` passed explicitly, so a changed upstream default cannot let a run write files. All three run from a scratch directory rather than the project.
- **`LlmProvider.requiresApiKey`** distinguishes providers that carry their own credentials. `SkillGenerator.hasAi` now turns on the provider rather than on a non-null key, so `claude-code` reaches the AI path with an empty config, and `apiKeyFor(claudeCode)` always returns `null` — a stray `ANTHROPIC_API_KEY` in the environment no longer makes `config --show` claim a key is in play.
- **`LlmClientFactory.create` accepts a nullable `apiKey`** and raises the new `MissingApiKeyException` for providers that need one, instead of relying on every call site to force-unwrap.
- **The CLI is invoked defensively.** The prompt goes over stdin, not argv, so a multi-megabyte facts payload cannot exceed the platform argument limit. A response wrapped in a single enclosing code fence is unwrapped, which a raw API rarely needs but an agent CLI often does, and plain-text output is accepted from an agent whose installed version does not support its JSON flag.
- **Failures degrade, they do not crash.** A missing binary or a failing run raises `AgentCliException extends LlmApiException`, so the existing template fallback covers it exactly as it covers a bad API key. `FLUTTER_SKILL_CLAUDE_BIN`, `FLUTTER_SKILL_CODEX_BIN`, and `FLUTTER_SKILL_GEMINI_BIN` point a provider at a CLI that is named differently or is not on PATH.
- **`analyze`, `sync`, and `watch` warn up front** when generation will fall back to templates — a missing key, or a missing agent binary — via the new `ResolvedProvider.unavailableReason`, which names the executable and the environment variable that repoints it. It stays a warning: a skill file is still produced.

### Ship as an Agent Skill

The analyzer does the scanning, an agent writes the prose, and the CLI verifies and assembles it. Three new commands split the model call out of the pipeline so any coding agent can stand in for it:

- **`flutter_skill_gen prompt`** scans the project and writes a `.skill_work/` handoff directory: `plan.json` (the scopes to write), `facts.json`, and one `prompts/<scope>.md` per planned skill file carrying the same system prompt and evidence-bearing JSON payload the API would have received. No model call, no key.
- **`flutter_skill_gen assemble`** reads `drafts/<scope>.md` back, runs every draft through `DraftVerifier` against the captured evidence bundle, splices in the generated diagrams and gotchas, adds frontmatter, and writes to every configured output target. `--clean` removes the work directory afterwards. Exit codes: `66` no workspace, `65` a missing or blank draft, `1` verification failed under `FLUTTER_SKILL_VERIFIER_MODE=fatal`.
- **`flutter_skill_gen install-skill`** installs the bundled Agent Skill into **both** `.claude/skills/flutter-skill-gen/` and `.agents/skills/flutter-skill-gen/` by default — between them, every agent that implements the standard. `--agent claude|codex|gemini|opencode|agents|all` narrows it, `--global` installs under the home directory, and `--output` targets any directory. Installation is all-or-nothing: if a skill already exists at either location, nothing is written until `--force` is passed, so a half-installed skill can never be current for one agent and stale for another. The skill teaches the agent the full loop, including the rules that otherwise corrupt output — no frontmatter, no wrapping fences, no hand-written Gotchas or Data Flow sections, and the per-scope line budget.
- **The skill is written for any agent, not just Claude Code.** Its first step checks the CLI with `--help` and looks for `prompt` in the command list, which also catches an install too old to have it, and it explains the `dart run flutter_skill_gen` form for projects where the package is a dev dependency. A test fails the build if the skill ever names a command or flag the CLI does not accept.
- **An agent-written draft is held to the same standard as an API-written one.** This matters more, not less: an agent can read the whole repository, so only the evidence bundle stops it asserting something plausible but absent. `SkillGenerator.assemble` and `assembleAll` verify before finishing, and `assembleAll` raises `MissingDraftException` for a scope the plan named but no draft covers.
- **Facts are written inside the workspace, not to `.skill_facts.json`.** A `prompt` run that is never assembled must not advance the baseline `sync` compares against, or the next `sync` would see no change and skip a SKILL.md that is still stale. `assemble` writes the root facts file at the end, as `analyze` does.
- **`assemble` warns when the project changed between the two commands**, naming the scopes that appeared or disappeared.

### Bug Fixes

- **Features nested inside a layer container were invisible.** `modules` was recognised as a feature container at the top level but not inside a layer, so a 655-file app with twelve features under `lib/ui/modules/` reported `organization: flat`, zero features, and collapsed to a single SKILL.md instead of thirteen. The failure was silent, and `--split` could not work around it: that flag unions the recommended scopes with `structure.featureDirs`, which was empty, so every unresolvable domain was dropped and the planner fell back to single-file mode. The nested container list is now derived from the top-level container names, and `StructureAnalyzer` and `DomainAnalyzer` share it rather than each keeping a copy that had drifted — so a container understood at the top level can never be missed when nested.
- **The verifier flagged correct statements that DI is centralized.** The per-feature DI check was a plain phrase match with no handling for negation, so a draft telling the reader this project does *not* use per-feature DI was annotated as unsupported. On a real thirteen-file run, eight of twelve `UNVERIFIED` markers were sentences like "DI is centralized through Riverpod providers rather than per-feature injection files" and "Don't create a per-feature DI/injection file". Both assert exactly what the evidence says. A per-feature phrase is now skipped when its clause carries a negation cue, scoped to the clause rather than the line so a stray negation earlier in a sentence cannot smuggle a genuine claim past the verifier.

### Known Limitations

- **The Codex and Gemini CLI providers are written from those tools' documented flags, not from a verified run.** `codex exec --sandbox read-only -` and `gemini --output-format json` were taken from the official docs; only the Claude Code provider has been exercised end to end. A wrong flag is not destructive — the run fails and falls back to template output with the CLI's own error — but treat those two providers as unconfirmed until someone with them installed reports back.
- **`--provider gemini-cli` needs a Gemini CLI new enough to accept `--output-format`.** Older builds reject it; the client accepts their plain-text output, so generation still works.
- **Illustrative class names are still read as claims.** A draft that writes `XxxInitState` as a placeholder, or "`LoginNotifier`-style" as a naming convention, has those tokens flagged as unknown classes, because the extractor matches any PascalCase word carrying a known suffix. Four of the twelve markers in the run above were this. Narrowing it risks weakening a check that does catch real hallucinations.
- **None of the agent-CLI providers suit CI.** A build server is not signed in to an agent. Keep using `FLUTTER_SKILL_API_KEY` there.

### Public API

- **New exports:** `AgentCli`, `AgentCliClient`, `AgentCliException`, `CliInvocation`, `CliInvoker`, `MissingApiKeyException`, `MissingDraftException`, `SkillWorkspace`, `WorkspacePlan`, `WorkspaceException`, `AgentSkillAsset`, `SkillLocation`.
- **New enum values `LlmProvider.claudeCode`, `LlmProvider.codex`, and `LlmProvider.geminiCli`**, plus the field `LlmProvider.requiresApiKey`. Exhaustive switches over `LlmProvider` in downstream code need new cases.
- **`LlmClientFactory.create`'s `apiKey` parameter is now `String?`** (was `String`). Existing call sites passing a non-null key are unaffected.
- **`ConfigManager.envVarFor` returns `''` for the three agent-CLI providers** — they read no key from the environment.

## 1.0.0

### Multi-Provider Support

Skill generation is no longer tied to Anthropic. A provider-agnostic `LlmClient` seam sits between `SkillGenerator` and the network, with three implementations behind a factory — the generator calls one `complete()` method and never learns which vendor answered.

- **Three providers.** `anthropic` (Claude Messages API, `x-api-key`), `openai` (any endpoint speaking OpenAI's `/chat/completions` shape, `Authorization: Bearer`), and `gemini` (Google's `generateContent`, `x-goog-api-key`). Selected with `--provider` on `analyze`, `sync`, `watch`, and `init`, or persisted with `flutter_skill_gen config --set-provider`.
- **OpenAI-compatible endpoints.** `--provider openai` combined with `--base-url` targets DeepSeek, Groq, Together, Fireworks, OpenRouter, and local Ollama or vLLM servers. `LlmProvider.tryParse` accepts `deepseek`, `groq`, `together`, `fireworks`, `openrouter`, `ollama`, and `openai-compatible` as aliases for `openai`, plus `claude` for `anthropic` and `google` for `gemini`, so `--provider deepseek --base-url …` reads naturally.
- **Provider-specific response handling.** Each client normalises its vendor's quirks rather than assuming a common shape: `OpenAiCompatibleClient` reads `choices[0].message.content`, surfaces `message.refusal`, and distinguishes a `finish_reason: length` truncation; `GeminiClient` reads `candidates[0].content.parts[]`, skips parts flagged `thought: true`, and reports `promptFeedback.blockReason` and `SAFETY`/`MAX_TOKENS` finish reasons, none of which arrive as HTTP errors.
- **Reasoning-model token field.** OpenAI's reasoning models reject `max_tokens` and name `max_completion_tokens` in the error. `OpenAiCompatibleClient` sends `max_tokens` first — the field every compatible provider understands — and retries once with `max_completion_tokens` only when a 400 response explicitly asks for it. Unrelated 400s are not retried.
- **`LlmApiException`** is the new provider-agnostic failure type. `ClaudeApiException` now extends it rather than implementing `Exception` directly, so existing `catch` sites and the exported type are unchanged, while `SkillGenerator`'s template fallback covers all three providers uniformly. A bad key, an unknown model, or a network error on any provider degrades to template output with a warning instead of failing the command.
- **New public exports:** `LlmClient`, `LlmProvider`, `LlmApiException`, `LlmClientFactory`, `OpenAiCompatibleClient`, `GeminiClient`, and `ResolvedProvider`.

### Bug Fixes — Thinking-Model Crash

- **`type 'Null' is not a subtype of type 'String' in type cast` on every request to a thinking-enabled model.** `ClaudeClient.complete` took `content.first` and cast its `text` field to `String`. Models that think by default when the `thinking` parameter is omitted — Claude Sonnet 5, Opus 5, Opus 4.8, Opus 4.7 — return a `thinking` block *first*, which has no `text` field, so the cast hit `null`. This killed the process on every AI-powered run against those models, in every project. The client now collects text by block **type** across all blocks, skipping thinking blocks and concatenating multi-block responses.
- **The crash also defeated the template fallback.** A `TypeError` is not a `ClaudeApiException`, so it slipped past the `catch` in `SkillGenerator._generateWithAi` and terminated the process instead of degrading to template generation. Failures that produce no usable text now raise `ClaudeApiException`, restoring the fallback.
- **Refusals and truncation are now reported, not mis-parsed.** `stop_reason: "refusal"` (an HTTP 200 carrying no content) raises with its `stop_details.category`, and a response whose budget was consumed before any text was produced reports the token limit and the block types received rather than failing obscurely.
- **`maxTokens` default raised from 8192 to 16000** across all three clients. Thinking tokens are drawn from the same budget, so 8192 risked the model spending the entire allowance reasoning and returning nothing on a large project.

### Bug Fixes — Deterministic Analysis

- **The same project produced different skill files on different machines.** `FileUtils.collectDartFiles` returned `listSync` results in raw filesystem order — which varies by platform and by the order files happened to be created — while its sibling `listSubdirectories` sorted. Every consumer inherited that nondeterminism: `CodeSampler` picked whichever matching file the filesystem happened to yield first, so the representative bloc / repository / usecase samples spliced into `.skill_facts.json` and into every AI prompt could differ between a developer's machine and CI, or between two clones of the same repository. Results are now sorted by path. A practical side effect: `sync`'s change detection compares against the previous `.skill_facts.json`, so unstable ordering could trigger regeneration — and a billable API call — when nothing had actually changed.
- **Restored three test fixtures that were never committed.** `sample_bloc_project` was missing its `home` (full clean-arch) and `cart` (presentation-only) features, and `sample_monorepo/app` had a `pubspec.yaml` with no `lib/`, so `StructureAnalyzer.analyze()` returned early at its missing-`lib/` guard and never evaluated package detection. Eight tests across `structure_analyzer`, `domain_analyzer`, and `project_scanner` had been asserting against a fixture that did not exist on disk. The fixtures now match what those tests describe — including `cart`'s deliberately absent `data/` and `domain/` layers, which is what proves layer detection is per-feature rather than project-wide.

### Per-Provider Configuration

`~/.flutter_skill_gen/config.yaml` gained three keys. Existing config files keep working untouched — nothing needs migrating.

- **`api_keys:` — a per-provider key map.** Keys are stored per provider, so configuring Gemini never overwrites your Anthropic key and switching back needs no re-entry. `--set-key` writes to the active provider's slot; pass `--set-provider` in the same command and the provider is switched first, so the key lands where you expect. `--remove-key` likewise clears only the active provider.
- **`provider:` and `base_url:`.** Set with `config --set-provider` and `config --set-base-url`; both are shown by `config --show`, alongside the provider a masked key belongs to.
- **The legacy flat `api_key:` field is still read**, as the last fallback, answering for whichever provider is active — so single-provider Anthropic setups written before 1.0.0 continue to work with no changes. `--remove-key` also drops it, since it would otherwise keep answering for every provider.
- **Provider environment variables.** `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, and `GEMINI_API_KEY` are now read for the active provider. Full resolution order: `FLUTTER_SKILL_API_KEY` → the provider's own variable → `api_keys.<provider>` → the legacy `api_key`.
- **Per-provider default models.** `ConfigManager.defaultModelFor` returns `claude-sonnet-5`, `gpt-5.6-sol`, or `gemini-3.8-flash`. Passing `--provider` *without* `--model` uses that provider's default rather than the stored model, which usually belongs to a different vendor and would 404.
- **Model aliases are Anthropic-scoped.** `sonnet` and `opus` name Claude models, so `ConfigManager.resolveModel` only expands them under `anthropic`; any other provider receives the value unchanged. The method gained an optional `provider:` parameter defaulting to `anthropic`, so existing calls are unaffected.
- **`ConfigManager` accepts an injected `environment` map**, making key-resolution behaviour testable and keeping the suite hermetic against ambient provider keys.

### Model Defaults

- **Bumped to the Claude 5 family.** The built-in default moved from `claude-sonnet-4-6` to `claude-sonnet-5`, and the `opus` alias from `claude-opus-4-7` to `claude-opus-5`. Unmapped IDs still pass through unchanged, so anyone with a specific model pinned in `~/.flutter_skill_gen/config.yaml` keeps calling that exact model.
- These two changes are coupled to the crash fix above: shipping the Claude 5 default *without* the block-parsing fix would have made the crash universal rather than opt-in.

### Behaviour Changes

Worth reading before upgrading:

- **Provider environment variables are now read.** If your shell already exports `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, or `GEMINI_API_KEY`, flutter_skill_gen will start using it. An install that previously produced template output with no configuration may now make real, billable API calls. `flutter_skill_gen config --show` reports the key that will actually be used, after the full resolution order.
- **The default model changed**, and `maxTokens` rose from 8192 to 16000. Both affect per-run cost.
- **`--set-key` writes to `api_keys.<provider>`**, not the flat `api_key:` field. Reads remain backward compatible.
- **`base_url` is a single global value, not per-provider.** Setting it for DeepSeek and later switching to plain OpenAI will still target DeepSeek until it is cleared with `config --set-base-url ""`.
- **Code samples may differ from 0.4.0 output.** Sorting `collectDartFiles` changes which file `CodeSampler` selects as the representative sample for a pattern, so regenerating an existing project can produce a different — but now stable — `.skill_facts.json` and skill file.
- **An unknown `--provider` value fails fast** rather than silently falling back: exit code `1` from `analyze`, `sync`, and `watch`, and `64` from `init` and `config --set-provider`.

### Documentation

- **README restructured around one `## AI Providers` section.** Provider, key, and model guidance previously sat in four sections spread across the file; setting up a non-default provider meant reading all four and reconciling them. They are now consolidated in reading order — pick a provider, set it up, use a compatible service, choose a model, where keys are read from, what happens when a call fails — with per-provider key sources, environment variables, and a troubleshooting table.
- Fixed a nesting bug where `### Project config (.skillrc.yaml)` had become a subsection of API-key documentation rather than of `## Configuration`.
- Quick Start now leads with the zero-configuration path, since skill generation has never required an API key.

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

### Default Model Update

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

### Documentation Updates

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
