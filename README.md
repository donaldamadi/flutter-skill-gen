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
- **No API key required** — use the coding agent you already have (Claude Code, OpenAI Codex, Gemini CLI, OpenCode), either as a provider (`--provider claude-code|codex|gemini-cli`) or through the bundled **Agent Skill**, where you just ask your agent to update your project context ([guide](#using-it-with-your-coding-agent-no-api-key))
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
  flutter_skill_gen: ^1.1.0
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

That works with no setup at all: the skill file is built from templates
filled with what the scan found. For richer, AI-written skill files, pick one:

| I want to... | Run this | Details |
| --- | --- | --- |
| Use my **coding agent's** login, no API key, from the terminal | `flutter_skill_gen analyze --provider claude-code` (or `codex`, `gemini-cli`) | [Option A](#option-a-the-tool-calls-your-agents-cli) |
| Just **ask my agent** to do it for me (the Agent Skill) | `flutter_skill_gen install-skill`, then ask it *"update the project context"* | [Option B](#option-b-the-agent-skill-your-agent-calls-the-tool) |
| Use a **local open-source model** | `flutter_skill_gen analyze --provider openai --base-url http://localhost:11434/v1` | [OpenAI-compatible](#using-openai-compatible-services) |
| Use an **API key** (Anthropic, OpenAI, Gemini, DeepSeek...) | `flutter_skill_gen config --set-key sk-ant-xxxxx` then `flutter_skill_gen analyze` | [AI Providers](#ai-providers) |

## Using it with your coding agent (no API key)

If you already use a coding agent — [Claude Code](https://claude.com/claude-code),
[OpenAI Codex](https://developers.openai.com/codex),
[Gemini CLI](https://geminicli.com), or
[OpenCode](https://opencode.ai) — you don't need an API key to get AI-written
skill files. There are two ways to do it, and this section explains both from
the ground up.

> **Is this still a Flutter/Dart package?** Yes. Nothing was taken away.
> You install it with `dart pub global activate flutter_skill_gen` exactly as
> before, and `analyze`, `sync`, `watch`, `init`, the git hooks, and API-key
> providers all work the same way. Agent support is an **extra** option on
> top.

### First: what the tool does, in three steps

Every time flutter_skill_gen produces a skill file, it goes through the same
three steps:

```text
┌───────────────────────────────────────────────────────────────────┐
│ 1. SCAN      Read your project: pubspec.yaml, folders, classes,   │
│              state management, DI, routing...                     │
│              → a list of FACTS, plus an EVIDENCE list: every      │
│                real file path and class name under lib/           │
├───────────────────────────────────────────────────────────────────┤
│ 2. WRITE     Turn those facts into clear, readable instructions   │
│              → this is the only step that needs an AI             │
├───────────────────────────────────────────────────────────────────┤
│ 3. CHECK     Compare what was written against the EVIDENCE list.  │
│    & FINISH  Anything that mentions a file or class that doesn't  │
│              exist is flagged. Then add diagrams, gotchas, and    │
│              frontmatter, and write the files.                    │
└───────────────────────────────────────────────────────────────────┘
```

Steps 1 and 3 are plain Dart code that runs on your machine. They're free
and need no setup.

Step 2 is where the AI comes in, and there are four ways to fill it:

| Who writes step 2 | How you run it | Needs an API key? |
| --- | --- | --- |
| Nobody: built-in templates | `flutter_skill_gen analyze` with nothing configured | No |
| A hosted AI (Anthropic, OpenAI, Gemini...) | `flutter_skill_gen analyze` with a key set | **Yes** |
| A local open-source model via Ollama | `flutter_skill_gen analyze --provider openai --base-url http://localhost:11434/v1` | No (a placeholder value is enough) |
| **Option A:** your agent's CLI, called by the tool | `flutter_skill_gen analyze --provider claude-code` (or `codex`, `gemini-cli`) | No |
| **Option B:** your agent, calling the tool (the **Agent Skill**) | Ask your agent in plain English | No |

Options A and B both use the agent you're already signed in to, so any usage
comes out of your existing plan instead of a separate API bill.

---

### Option A: the tool calls your agent's CLI

**In one sentence:** you run the usual command, and flutter_skill_gen quietly
asks your local agent to do the writing.

**Who's in charge:** flutter_skill_gen. You run one command and get finished
files, just like with an API key.

#### Supported agents

| Your agent | `--provider` | Command it runs | Points elsewhere with |
| --- | --- | --- | --- |
| Claude Code | `claude-code` | `claude --print` | `FLUTTER_SKILL_CLAUDE_BIN` |
| OpenAI Codex | `codex` | `codex exec` | `FLUTTER_SKILL_CODEX_BIN` |
| Gemini CLI | `gemini-cli` | `gemini --output-format json` | `FLUTTER_SKILL_GEMINI_BIN` |

> `gemini-cli` drives the program on your machine. The separate `gemini`
> provider calls Google's hosted API and **does** need a key, so don't mix
> them up.

#### Setup

1. Install your agent's CLI and sign in, so that running `claude`, `codex`, or
   `gemini` works in your terminal.
2. Install flutter_skill_gen if you haven't already:

   ```bash
   dart pub global activate flutter_skill_gen
   ```

3. Run it with the matching provider:

   ```bash
   flutter_skill_gen analyze --provider claude-code
   flutter_skill_gen analyze --provider codex
   flutter_skill_gen analyze --provider gemini-cli
   ```

To use it every time without typing the flag:

```bash
flutter_skill_gen config --set-provider claude-code
flutter_skill_gen analyze
```

Check your setup at any time:

```bash
flutter_skill_gen config --show
```

With one of these providers active, this shows `api_key: (not needed …)` and
tells you whether the program was found on your `PATH`.

#### What happens behind the scenes

```text
flutter_skill_gen analyze --provider claude-code
   │
   ├─ 1. SCAN     flutter_skill_gen reads your project
   │
   ├─ 2. WRITE    flutter_skill_gen runs your agent's CLI in the background
   │              and hands it the facts. The agent writes the text.
   │
   └─ 3. CHECK    flutter_skill_gen checks the text against the evidence
                  and writes SKILL.md (and any other output targets)
```

#### Safety: what the agent can and can't do here

While generating, the agent is locked down:

- It runs from a temporary folder, not your project, so the scanned facts are
  all it sees. This applies to every agent.
- Claude Code additionally has its file, shell, and web tools switched off for
  the call; Codex is run with `--sandbox read-only`, which blocks writes.
- Your project data is piped to it directly and isn't written anywhere else.

#### Choosing a model

Whatever you pass to `--model` goes straight to the agent's CLI, so its own
model names work:

```bash
flutter_skill_gen analyze --provider claude-code --model opus
flutter_skill_gen analyze --provider codex --model gpt-5.6-sol
```

#### Where Option A works

Everywhere the normal tool works: `analyze`, `sync`, `watch`, `init`, and
the git hooks.

> **Heads-up:** if you make one of these your default provider, then `watch`
> and the pre-commit hook will call your agent whenever your project's facts
> change. That's slower than an API call and uses your plan. `sync` skips
> regeneration when nothing meaningful changed, which keeps this in check.
>
> **Not for CI:** a CI server usually isn't signed in to any agent, so keep
> using an API key (`FLUTTER_SKILL_API_KEY`) there.

#### If the program isn't found

Nothing breaks. You'll see a warning, and the tool falls back to template
output, so you still get a skill file. If your agent is installed under a
different name or outside your `PATH`, point the tool at it with the
environment variable from the table above:

```bash
export FLUTTER_SKILL_CLAUDE_BIN=/full/path/to/claude
export FLUTTER_SKILL_CODEX_BIN=/full/path/to/codex
export FLUTTER_SKILL_GEMINI_BIN=/full/path/to/gemini
```

---

### Option B: the Agent Skill (your agent calls the tool)

**In one sentence:** you ask your agent to "update the project context", and
it runs flutter_skill_gen for you, writes the text itself, and fixes its own
mistakes.

**Who's in charge:** your agent. You don't run the commands yourself.

#### What is an "Agent Skill"?

An Agent Skill is a small instruction file (`SKILL.md`) that a coding agent
reads to learn how to do a particular job. The agent looks in a skills folder,
picks up the file's short description, and follows the instructions whenever
your request matches.

It's an [open standard](https://agentskills.io/specification), so the same
file works across agents. flutter_skill_gen **ships with** an Agent Skill that
teaches any of them how to generate and maintain Flutter skill files with this
tool.

| Agent | Reads skills from | Works with our skill? |
| --- | --- | --- |
| Claude Code | `.claude/skills/` | ✅ |
| OpenAI Codex | `.agents/skills/`, `~/.agents/skills/` | ✅ |
| Gemini CLI | `.gemini/skills/`, `.agents/skills/` | ✅ |
| OpenCode | `.claude/skills/` **and** `.agents/skills/` | ✅ |

`install-skill` writes to **both** `.claude/skills/` and `.agents/skills/` by
default, so one command covers all of them.

> **Important:** the Agent Skill is instructions only, and it **needs the
> flutter_skill_gen package installed** to work. The package does the scanning
> (step 1) and the checking (step 3). The agent only does the writing
> (step 2). This split is on purpose: the checker is what stops an agent from
> confidently describing files that don't exist.
>
> The skill is built into the package, so every package version always
> installs the matching skill. There's nothing separate to download or keep
> in sync.

#### Setup (one time)

**Step 1: install the package** (if you haven't):

```bash
dart pub global activate flutter_skill_gen
```

**Step 2: install the Agent Skill.** From your Flutter project's folder:

```bash
flutter_skill_gen install-skill
```

That's it. Next time you start your agent in this project, it knows the skill.

#### Where the skill gets installed

| Command | Installs to | Use it when |
| --- | --- | --- |
| `flutter_skill_gen install-skill` | `.claude/skills/…` **and** `.agents/skills/…` in your project | The default. Covers every agent. Commit it and your whole team gets it. |
| `flutter_skill_gen install-skill --global` | The same two folders in your home directory | You want it in every project on your machine. |
| `flutter_skill_gen install-skill --agent claude` | `.claude/skills/…` only | You only use Claude Code. |
| `flutter_skill_gen install-skill --agent codex` | `.agents/skills/…` only | You only use Codex, Gemini CLI, or OpenCode. |
| `flutter_skill_gen install-skill --output <folder>` | `<folder>/SKILL.md` | You keep skills somewhere custom. |
| `flutter_skill_gen install-skill --path <project>` | Both folders in that project | You're installing into a project other than the current folder. |

`--agent` accepts `all` (the default), `claude`, `codex`, `gemini`,
`opencode`, and `agents`. Codex, Gemini CLI, and OpenCode all read
`.agents/skills/`, so they map to the same place.

If a skill file is already there, the command installs nothing and tells you,
in case you edited it. Add `--force` to replace it with the latest version,
which is worth doing after you upgrade the package.

#### Using it

Open your agent in your Flutter project and ask in plain English. For example:

- *"Generate the project context files for this repo."*
- *"Update the SKILL.md, I renamed the auth feature."*
- *"Refresh the AI context docs for this Flutter app."*
- *"Create an AGENTS.md / .cursorrules for this project."*

#### What the agent does next, step by step

```text
You: "Update the project context for this repo."
   │
   ▼
Your agent finds the flutter-skill-gen skill and follows it:
   │
   ├─ ① Checks the tool is installed
   │     runs: flutter_skill_gen --help
   │     (installs or upgrades it with `dart pub global activate` if needed)
   │
   ├─ ② SCAN — runs: flutter_skill_gen prompt
   │     flutter_skill_gen scans your project and creates a .skill_work/ folder
   │     containing a plan and one set of instructions per file to write
   │
   ├─ ③ WRITE — the agent reads each instruction file and writes a draft
   │     into .skill_work/drafts/. It can also open your real source code
   │     for better detail.
   │
   ├─ ④ CHECK — runs: flutter_skill_gen assemble
   │     flutter_skill_gen checks every draft against the evidence.
   │     If something is wrong, it says exactly what, for example:
   │
   │        line 8 [unknownFilePath]:
   │          lib/features/cart/data/repositories/cart_repository_impl.dart
   │          — path not present in lib/ manifest
   │
   │     The agent fixes the draft and runs assemble again.
   │
   └─ ⑤ FINISH — once the drafts pass, flutter_skill_gen adds diagrams,
         gotchas, and frontmatter, writes every configured output file
         (SKILL.md, CLAUDE.md, .cursorrules, AGENTS.md...), and cleans up.
```

You end up with the same files `analyze` would produce, usually more
detailed, because the agent could read your actual code while writing.

#### The `.skill_work/` folder

`flutter_skill_gen prompt` creates a temporary work folder in your project.
Here's what's in it:

| Path | What it is | Who writes it |
| --- | --- | --- |
| `.skill_work/plan.json` | The list of skill files to write, e.g. `core`, `auth`, `cart` | flutter_skill_gen |
| `.skill_work/facts.json` | Everything the scan found | flutter_skill_gen |
| `.skill_work/prompts/<name>.md` | Instructions and facts for one file: what sections to include, line limits, and the evidence list | flutter_skill_gen |
| `.skill_work/drafts/<name>.md` | The draft text for one file | **Your agent (or you)** |

Small projects get a single `core` file. Larger ones are split into `core`
plus one file per feature (`auth`, `cart`, `home`...), just like `analyze`
does. `flutter_skill_gen assemble --clean` deletes the folder once
everything passes.

It's safe to add `.skill_work/` to your `.gitignore`.

#### How strict the checker is

By default, `assemble` **flags** unsupported claims: it keeps the line but
marks it with an `<!-- [UNVERIFIED: …] -->` comment, so you can see what to
review. You can make it stricter or quieter:

| Setting | What happens to an unsupported claim |
| --- | --- |
| *(default)* `annotate` | Kept, with an `UNVERIFIED` marker next to it |
| `FLUTTER_SKILL_VERIFIER_MODE=strip` | The line is removed |
| `FLUTTER_SKILL_VERIFIER_MODE=fatal` | Nothing is written, and `assemble` exits with an error listing every problem |

```bash
FLUTTER_SKILL_VERIFIER_MODE=fatal flutter_skill_gen assemble
```

The Agent Skill tells the agent about `fatal` mode, so it can fix every
problem before anything is written.

What counts as "unsupported":

- A file path under `lib/` that doesn't exist in your project
- A class name that isn't declared anywhere in `lib/`
- A file-name pattern like `*_cubit.dart` that matches no file
- Saying dependency injection is "per feature" when the scan found it's
  set up in one central place

#### Keeping the files up to date

Just ask your agent again whenever your project changes. `prompt` always
rescans from scratch, so the files reflect your project as it is now.

For small changes, the skill tells the agent it can start from your existing
skill file and edit it rather than rewriting everything. That keeps the
wording stable from one update to the next.

#### Doing it without an agent

The `prompt` → write → `assemble` loop isn't tied to any particular tool. You,
or any other AI tool, can write the drafts:

```bash
flutter_skill_gen prompt              # 1. scan and create .skill_work/
# 2. write .skill_work/drafts/<name>.md for each name in .skill_work/plan.json,
#    following the instructions in .skill_work/prompts/<name>.md
flutter_skill_gen assemble --clean    # 3. check, finish, write, clean up
```

#### Rules for writing a draft

The instruction files spell these out, but these are the ones that matter most:

- **Don't add YAML frontmatter** (the `---` block at the top). It's added for you.
- **Don't wrap the draft in a code block.**
- **Don't write a "Gotchas" or "Data Flow" section.** Both are generated
  automatically, and writing your own creates duplicates.
- **Stay under the line limit:** under 180 lines for a single-file skill,
  under 150 for the `core` file of a split project, and under 120 for a
  feature file.
- **Only mention files and classes that appear in the evidence list.** If
  you want to describe something that isn't there, describe the pattern in
  general terms instead.

---

### Which option should I use?

| | **Option A** (`--provider <agent>`) | **Option B** (Agent Skill) |
| --- | --- | --- |
| How you start it | A terminal command | A sentence in your agent |
| Who writes the text | Your agent, in the background | Your agent, in your session |
| Can it read your actual source code? | No, only the scanned facts | Yes, the whole project |
| Checked against the evidence? | Yes | Yes |
| Works with `watch`, git hooks, `sync` | Yes | No (it needs you in an agent session) |
| Works in CI | No (use an API key there) | No (use an API key there) |
| Agents | Claude Code, Codex, Gemini CLI | Any agent reading the Agent Skills standard |
| Typical quality | Good | Usually better, since it has more context |
| Best for | Automatic, hands-off updates | Deliberate "refresh the docs" moments |

**You can use both.** For example, let the git hook keep things current with
Option A, and ask your agent (Option B) for a thorough refresh after a big
refactor.

### Common questions

**Do I still need Dart installed to use the Agent Skill?**
Yes. The skill runs the flutter_skill_gen command, which is a Dart program.
If you're working on a Flutter project, you already have Dart.

**Can I use the Agent Skill if flutter_skill_gen is a dev dependency instead
of globally installed?**
Yes. The skill tells the agent to run `dart run flutter_skill_gen …` in that case.

**Does the Agent Skill send my code anywhere?**
Only to the agent you're already using. flutter_skill_gen itself makes no
network calls in `prompt` or `assemble`.

**Can I use an open-source or local model?**
Yes, two ways. Run an agent that supports them — OpenCode reads our skill and
works with local models — or skip the agent entirely and point the tool at a
local server: `flutter_skill_gen analyze --provider openai --base-url
http://localhost:11434/v1 --model qwen2.5-coder`. Ollama ignores the key, but
one has to be set to some placeholder value.

**Which agents can use the Agent Skill?**
Any that implement the [Agent Skills standard](https://agentskills.io/specification).
Verified layouts: Claude Code, OpenAI Codex, Gemini CLI, and OpenCode. If
yours reads skills from somewhere else, install with
`--output <that folder>/flutter-skill-gen`.

**Does it overwrite files I've edited by hand?**
It writes the same output files `analyze` does (for example `SKILL.md`,
`CLAUDE.md`, `.cursorrules`), so yes, those get regenerated. It never
overwrites the installed Agent Skill itself unless you pass `--force`.

**Which output files do I get?**
Whatever is configured in `.skillrc.yaml` (see [Output Formats](#output-formats)).
Both options respect it.

**I upgraded flutter_skill_gen. Do I need to do anything?**
Run `flutter_skill_gen install-skill --force` to get the latest version of
the Agent Skill.

**Can I still use my API key?**
Yes. Nothing about API-key providers changed. See [AI Providers](#ai-providers).

### Troubleshooting

| What you see | What it means | What to do |
| --- | --- | --- |
| `Could not run "claude"` (or `codex`, `gemini`) | Option A can't find your agent | Install it, or set `FLUTTER_SKILL_CLAUDE_BIN` / `FLUTTER_SKILL_CODEX_BIN` / `FLUTTER_SKILL_GEMINI_BIN` to its full path |
| `The "codex" CLI is not on your PATH` warning | Same as above, caught before generating | Same as above. You still get template output. |
| `claude exited with code 1: …` | The agent ran but failed (often a sign-in or plan-limit issue) | Run the agent on its own to see the problem |
| `No workspace found at …/.skill_work` (exit code `66`) | `assemble` was run before `prompt` | Run `flutter_skill_gen prompt` first |
| `No draft for 1 scope(s): cart` (exit code `65`) | A draft is missing or empty | Write `.skill_work/drafts/cart.md`, then run `assemble` again |
| `Draft verification failed` (exit code `1`) | A draft mentions something that doesn't exist, in `fatal` mode | Fix the listed lines in the drafts and run `assemble` again |
| `The project changed since "prompt" ran` warning | Features were added or removed between `prompt` and `assemble` | Run `flutter_skill_gen prompt` again for a fresh scan |
| `… already exists. Re-run with --force` (exit code `73`) | An Agent Skill is already installed there | Add `--force` to replace it |
| `… already exists` listing two paths | The default install found a skill in one of its two folders | Add `--force`, or narrow it with `--agent` |
| Your agent doesn't seem to use the skill | It was installed where that agent doesn't look, or your session started before it existed | Start a new session from the project folder, check the folder your agent reads (see the table in Option B), or mention "the flutter-skill-gen skill" in your request |

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

Six providers are supported. Three call a hosted API with a key; three drive a
coding agent already installed on your machine and need no key at all:

| `--provider` | Service | Get a key from | Environment variable |
| --- | --- | --- | --- |
| `anthropic` *(default)* | Claude | [console.anthropic.com](https://console.anthropic.com/settings/keys) | `ANTHROPIC_API_KEY` |
| `openai` | OpenAI + compatible services | [platform.openai.com](https://platform.openai.com/api-keys) | `OPENAI_API_KEY` |
| `gemini` | Google Gemini | [aistudio.google.com](https://aistudio.google.com/apikey) | `GEMINI_API_KEY` |
| `claude-code` | Your local Claude Code CLI | *(no key — uses its own sign-in)* | — |
| `codex` | Your local OpenAI Codex CLI | *(no key — uses its own sign-in)* | — |
| `gemini-cli` | Your local Gemini CLI | *(no key — uses its own sign-in)* | — |

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

### Without an API key

The `claude-code`, `codex`, and `gemini-cli` providers use your existing agent
sign-in instead of a key:

```bash
flutter_skill_gen config --set-provider claude-code
flutter_skill_gen config --set-provider codex
flutter_skill_gen config --set-provider gemini-cli
```

For the full picture, including the Agent Skill where your agent runs the
whole process for you, see
[Using it with your coding agent](#using-it-with-your-coding-agent-no-api-key).

### Using OpenAI-compatible services

`--provider openai` works with any service that speaks OpenAI's API shape. Point
it at one with `--base-url`:

```bash
# DeepSeek
flutter_skill_gen analyze \
  --provider openai \
  --base-url https://api.deepseek.com/v1 \
  --model deepseek-chat

# A local Ollama server running an open-source model.
# No real key is needed — Ollama ignores it — but one must be set to
# some placeholder value.
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

### Selecting a model

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
| `claude-code` | `sonnet` |
| `codex` | `gpt-5.6-sol` |
| `gemini-cli` | `gemini-3.8-flash` |

Two things worth knowing:

- The `sonnet` and `opus` shortcuts name Claude models, so they only expand under
  `anthropic`. Any other provider receives the value unchanged.
- OpenAI and Google rename and retire model IDs often. Set `--model` explicitly
  for those two rather than relying on the defaults above.
- `claude-code`, `codex`, and `gemini-cli` pass `--model` straight to the
  agent's own CLI, so they take whatever names that CLI accepts (`sonnet`,
  `opus`, or a full model ID).

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
| `Could not run "claude"` (or `codex`, `gemini`) | That agent's CLI is not on your `PATH`. Install it, or set `FLUTTER_SKILL_CLAUDE_BIN` / `FLUTTER_SKILL_CODEX_BIN` / `FLUTTER_SKILL_GEMINI_BIN`. |
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

### `prompt` / `assemble`

The two commands behind the Agent Skill. `prompt` scans the project and
writes instructions; someone (your coding agent, another AI tool, or you)
writes the drafts; `assemble` checks them and writes the final files. Neither command
calls an AI or reads an API key. See
[Option B](#option-b-the-agent-skill-your-agent-calls-the-tool) for the full
walkthrough.

```bash
# 1. Scan and create .skill_work/ with one instruction file per skill file
flutter_skill_gen prompt

# 2. Write .skill_work/drafts/<name>.md for each name in .skill_work/plan.json

# 3. Check the drafts, finish them, write every output target, clean up
flutter_skill_gen assemble --clean
```

**`prompt` options:**

| Option | What it does |
| --- | --- |
| `--path`, `-p` | Project to scan (default: current folder) |
| `--work-dir` | Where to create the work folder (default: `.skill_work/` in the project) |
| `--split` / `--no-split` | Force one file per feature, or force a single file (default: decided by project size) |
| `--verbose`, `-v` | Show more detail |

**`assemble` options:**

| Option | What it does |
| --- | --- |
| `--path`, `-p` | Project folder (default: current folder) |
| `--output`, `-o` | Where to write the final files (default: the project folder) |
| `--work-dir` | Where the work folder is (default: `.skill_work/` in the project) |
| `--clean` | Delete the work folder after a successful run |
| `--verbose`, `-v` | Show more detail |

**`assemble` exit codes:**

| Code | Meaning |
| --- | --- |
| `0` | Success |
| `1` | A draft mentions something that doesn't exist (only with `FLUTTER_SKILL_VERIFIER_MODE=fatal`) |
| `65` | A draft is missing or empty |
| `66` | No work folder found; run `prompt` first |

### `install-skill`

Installs the Agent Skill, the instruction file that teaches a coding agent how
to run `prompt` → write → `assemble` for you. See
[Option B](#option-b-the-agent-skill-your-agent-calls-the-tool).

```bash
# Into this project, for every agent (commit it to share with your team)
flutter_skill_gen install-skill

# Into your home directory, for every project on this machine
flutter_skill_gen install-skill --global

# Only for one agent
flutter_skill_gen install-skill --agent claude
flutter_skill_gen install-skill --agent codex

# Into a folder of your choice
flutter_skill_gen install-skill --output ./tools/skills/flutter-skill-gen

# Replace an existing copy, e.g. after upgrading the package
flutter_skill_gen install-skill --force
```

| Option | What it does |
| --- | --- |
| `--path`, `-p` | Project to install into (default: current folder) |
| `--agent`, `-a` | Which agent to install for: `all` (default), `claude`, `codex`, `gemini`, `opencode`, `agents` |
| `--global`, `-g` | Install into your home directory instead of the project |
| `--output`, `-o` | Install into this exact folder instead |
| `--force`, `-f` | Overwrite an existing skill file |

By default it writes to both `.claude/skills/flutter-skill-gen/` and
`.agents/skills/flutter-skill-gen/`, which between them cover Claude Code,
OpenAI Codex, Gemini CLI, and OpenCode. If a skill already exists at either
location, nothing is installed until you pass `--force`.

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

# Switch provider (anthropic, openai, gemini, claude-code, codex, gemini-cli)
flutter_skill_gen config --set-provider openai

# Use a local agent's sign-in instead of an API key
flutter_skill_gen config --set-provider claude-code

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

1. **Static Scanner** reads the project and extracts structured facts into `.skill_facts.json`, plus an **evidence bundle**: every real file path and class name under `lib/`
2. **Split Planner** decides whether to generate a single skill file or split into core + feature files based on project complexity
3. **Writing**: the prose comes from one of:
   - a hosted AI provider (Anthropic, OpenAI-compatible, Gemini) with an API key
   - a coding agent installed on your machine, via `--provider claude-code`, `codex`, or `gemini-cli`
   - your agent in its own session, via the Agent Skill (`prompt` → drafts → `assemble`)
   - built-in templates, when none of the above is available
4. **Draft Verifier** checks AI-written text against the evidence bundle and flags, strips, or rejects any file, class, or pattern that doesn't exist
5. **Deterministic sections** (data-flow diagrams and gotchas) and spec-compliant frontmatter are added
6. **Target Writer** writes to every configured AI tool's native format simultaneously

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
