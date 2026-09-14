import 'dart:convert';
import 'dart:io';

import 'llm_client.dart';

/// The outcome of running an external command.
class CliInvocation {
  /// Creates a [CliInvocation].
  const CliInvocation({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  /// Process exit code.
  final int exitCode;

  /// Everything the process wrote to stdout.
  final String stdout;

  /// Everything the process wrote to stderr.
  final String stderr;
}

/// Runs [executable] with [arguments], feeding it [stdin].
///
/// Injected into [AgentCliClient] so tests can drive it without
/// spawning a real process.
typedef CliInvoker =
    Future<CliInvocation> Function(
      String executable,
      List<String> arguments, {
      required String stdin,
      required String workingDirectory,
    });

/// One coding-agent CLI this tool knows how to drive.
///
/// Each agent exposes a non-interactive mode that takes a prompt and
/// prints an answer. They differ in the flag that turns it on, whether
/// a separate system prompt is accepted, and how the answer comes
/// back, so the differences live here rather than in three
/// near-identical clients.
class AgentCli {
  /// Creates an [AgentCli] description.
  const AgentCli({
    required this.id,
    required this.executable,
    required this.executableEnvVar,
    required this.defaultModel,
    required this.buildArguments,
    this.resultField,
    this.acceptsSystemPrompt = true,
  });

  /// Stable identifier, matching the provider id on the CLI.
  final String id;

  /// Default executable name, used when nothing overrides it.
  final String executable;

  /// Environment variable that points at a different executable.
  final String executableEnvVar;

  /// Model passed when the config names none.
  final String defaultModel;

  /// Builds the argument list for one completion.
  final List<String> Function({
    required String model,
    required String systemPrompt,
  })
  buildArguments;

  /// JSON field holding the answer, or `null` when the agent prints
  /// the answer as plain text.
  final String? resultField;

  /// Whether the agent takes the system prompt as its own flag. When
  /// `false`, the instructions are folded into the prompt instead.
  final bool acceptsSystemPrompt;

  /// Claude Code (`claude`).
  ///
  /// `--system-prompt` replaces Claude Code's own agent prompt, so the
  /// call behaves like a plain completion, and the tools that could
  /// touch the project are denied outright.
  static final claudeCode = AgentCli(
    id: 'claude-code',
    executable: 'claude',
    executableEnvVar: 'FLUTTER_SKILL_CLAUDE_BIN',
    defaultModel: 'sonnet',
    resultField: 'result',
    buildArguments: ({required model, required systemPrompt}) => [
      '--print',
      '--output-format',
      'json',
      '--model',
      model,
      '--system-prompt',
      systemPrompt,
      '--disallowed-tools',
      deniedTools.join(','),
    ],
  );

  /// OpenAI Codex (`codex exec`).
  ///
  /// `exec` prints only the final message on stdout and takes the
  /// prompt from stdin when passed `-`. It has no system-prompt flag,
  /// so the instructions are prepended to the prompt. `--sandbox
  /// read-only` is Codex's own default but is passed explicitly so a
  /// changed default cannot let a generation run write files.
  static final codex = AgentCli(
    id: 'codex',
    executable: 'codex',
    executableEnvVar: 'FLUTTER_SKILL_CODEX_BIN',
    defaultModel: 'gpt-5.6-sol',
    acceptsSystemPrompt: false,
    buildArguments: ({required model, required systemPrompt}) => [
      'exec',
      '--sandbox',
      'read-only',
      '--model',
      model,
      '-',
    ],
  );

  /// Gemini CLI (`gemini --prompt`).
  ///
  /// Headless mode reads the prompt from stdin. `--output-format json`
  /// returns `{"response": …}` on versions that support it; older
  /// builds print plain text, which [AgentCliClient] also accepts.
  static final geminiCli = AgentCli(
    id: 'gemini-cli',
    executable: 'gemini',
    executableEnvVar: 'FLUTTER_SKILL_GEMINI_BIN',
    defaultModel: 'gemini-3.8-flash',
    resultField: 'response',
    acceptsSystemPrompt: false,
    buildArguments: ({required model, required systemPrompt}) => [
      '--model',
      model,
      '--output-format',
      'json',
    ],
  );

  /// Every agent CLI this tool can drive.
  static List<AgentCli> get all => [claudeCode, codex, geminiCli];

  /// Tools withheld from agents that can restrict them individually.
  ///
  /// Skill generation is a pure text transformation — every fact the
  /// model needs is already in the prompt — so denying the tools that
  /// touch the filesystem, the shell, and the network removes any
  /// chance of a generation run editing the project it describes.
  static const deniedTools = [
    'Bash',
    'Edit',
    'Write',
    'NotebookEdit',
    'WebFetch',
    'WebSearch',
    'Task',
  ];
}

/// Drives a locally installed coding-agent CLI instead of calling a
/// hosted API.
///
/// This is what makes keyless generation possible: the CLI
/// authenticates with the credentials the user's agent already holds,
/// so someone with a Claude, ChatGPT, or Gemini subscription never has
/// to mint an API key.
///
/// The prompt is delivered on stdin rather than as an argument, which
/// keeps large fact payloads clear of the platform's argument-length
/// limit.
class AgentCliClient implements LlmClient {
  /// Creates an [AgentCliClient] for [agent].
  ///
  /// [executable] overrides the command to run, [model] is the value
  /// passed to `--model`, and [extraArgs] are additional flags to
  /// forward — an escape hatch for options this client does not model
  /// itself. Pass [invoker] to stub out process execution in tests,
  /// and [workingDirectory] to override the scratch directory the CLI
  /// is run in.
  AgentCliClient({
    required this.agent,
    String? model,
    String? executable,
    this.extraArgs = const [],
    CliInvoker? invoker,
    String? workingDirectory,
  }) : model = model ?? agent.defaultModel,
       executable = executable ?? agent.executable,
       _invoke = invoker ?? _runProcess,
       _workingDirectory = workingDirectory;

  /// Which agent CLI to drive.
  final AgentCli agent;

  /// Model alias or ID passed to the agent's `--model` flag.
  final String model;

  /// The executable name or path.
  final String executable;

  /// Extra arguments appended to every invocation.
  final List<String> extraArgs;

  final CliInvoker _invoke;

  String? _workingDirectory;
  Directory? _scratchDir;

  /// Resolves the executable to run for [agent] from [environment].
  static String resolveExecutable(
    AgentCli agent, [
    Map<String, String>? environment,
  ]) {
    final env = environment ?? Platform.environment;
    final override = env[agent.executableEnvVar];
    if (override != null && override.isNotEmpty) return override;
    return agent.executable;
  }

  /// Returns whether [executable] is resolvable on PATH.
  ///
  /// Used to decide whether keyless generation is actually available
  /// before a run commits to it.
  static bool isAvailable({required String executable}) {
    try {
      final which = Platform.isWindows ? 'where' : 'which';
      return Process.runSync(which, [executable]).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  /// Sends [systemPrompt] and [userMessage] through the agent CLI and
  /// returns the assistant's text.
  ///
  /// [maxTokens] is accepted for interface compatibility but ignored —
  /// print mode exposes no equivalent flag.
  @override
  Future<String> complete({
    required String systemPrompt,
    required String userMessage,
    int maxTokens = 16000,
  }) async {
    final arguments = <String>[
      ...agent.buildArguments(model: model, systemPrompt: systemPrompt),
      ...extraArgs,
    ];

    // Agents without a system-prompt flag get the instructions at the
    // top of the prompt instead, so every agent receives the same
    // grounding rules the API providers do.
    final prompt = agent.acceptsSystemPrompt
        ? userMessage
        : '$systemPrompt\n\n---\n\n$userMessage';

    final CliInvocation invocation;
    try {
      invocation = await _invoke(
        executable,
        arguments,
        stdin: prompt,
        workingDirectory: _resolveWorkingDirectory(),
      );
    } on ProcessException catch (e) {
      throw AgentCliException(
        'Could not run "$executable": ${e.message}. '
        'Install ${agent.id}, point ${agent.executableEnvVar} at it, '
        'or pick a provider with an API key.',
      );
    }

    if (invocation.exitCode != 0) {
      throw AgentCliException(
        '$executable exited with code ${invocation.exitCode}: '
        '${_firstLine(invocation.stderr, invocation.stdout)}',
      );
    }

    return _extractResult(invocation.stdout);
  }

  /// Pulls the assistant text out of the agent's output.
  ///
  /// Agents that print JSON name the answer in
  /// [AgentCli.resultField]. Plain-text output is taken as-is, which
  /// also covers a JSON-capable agent whose installed version does not
  /// yet support the flag.
  String _extractResult(String stdout) {
    final text = stdout.trim();
    if (text.isEmpty) {
      throw AgentCliException('$executable returned no output');
    }

    final field = agent.resultField;
    if (field == null) return _finish(text);

    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      // Not JSON: an older build that ignores the output-format flag
      // still printed a usable answer.
      return _finish(text);
    }

    if (decoded is! Map<String, dynamic>) return _finish(text);

    final result = decoded[field];
    if (decoded['is_error'] == true) {
      throw AgentCliException(
        '$executable reported an error '
        '(${decoded['subtype'] ?? 'unknown'}): '
        '${result is String ? result : 'no detail'}',
      );
    }

    if (result is! String || result.trim().isEmpty) {
      throw AgentCliException('$executable returned no text');
    }

    return _finish(result);
  }

  String _finish(String text) => _stripEnclosingFence(text.trim());

  /// Removes a fence that wraps the entire response.
  ///
  /// The system prompt asks for raw markdown, but an agent CLI is
  /// more inclined than a raw API to wrap its answer in
  /// ```` ```markdown ````. Left in place the fence ends up inside
  /// SKILL.md, so it is stripped when — and only when — it encloses
  /// the whole response.
  String _stripEnclosingFence(String text) {
    if (!text.startsWith('```') || !text.endsWith('```')) return text;

    final lines = text.split('\n');
    if (lines.length < 3) return text;

    final opening = lines.first.trim();
    // A language tag is fine; anything else means the first line is
    // not a plain opening fence.
    if (opening.substring(3).contains('`')) return text;
    if (lines.last.trim() != '```') return text;

    // Any other fence in between means the response contains code
    // blocks of its own and the outer pair is not an enclosure.
    final inner = lines.sublist(1, lines.length - 1);
    if (inner.any((line) => line.trimLeft().startsWith('```'))) return text;

    return inner.join('\n').trim();
  }

  String _resolveWorkingDirectory() {
    final existing = _workingDirectory;
    if (existing != null) return existing;

    // Run outside the project being analysed. Every fact is already in
    // the prompt, so the CLI has no reason to read the project — and
    // from a scratch directory it cannot.
    final dir = Directory.systemTemp.createTempSync('flutter_skill_gen_');
    _scratchDir = dir;
    return _workingDirectory = dir.path;
  }

  static String _firstLine(String primary, String fallback) {
    final source = primary.trim().isEmpty ? fallback : primary;
    final trimmed = source.trim();
    if (trimmed.isEmpty) return 'no output';
    final newline = trimmed.indexOf('\n');
    return newline == -1 ? trimmed : trimmed.substring(0, newline);
  }

  /// Removes the scratch directory created for the CLI, if any.
  @override
  void close() {
    final dir = _scratchDir;
    _scratchDir = null;
    if (dir == null) return;
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // A leftover empty temp directory is not worth failing a run.
    }
  }

  static Future<CliInvocation> _runProcess(
    String executable,
    List<String> arguments, {
    required String stdin,
    required String workingDirectory,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );

    // Start draining both streams before feeding stdin: a large
    // prompt plus an un-drained stdout pipe is a deadlock.
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();

    process.stdin.write(stdin);
    await process.stdin.close();

    final exitCode = await process.exitCode;
    return CliInvocation(
      exitCode: exitCode,
      stdout: await stdoutFuture,
      stderr: await stderrFuture,
    );
  }
}

/// Exception thrown when an agent CLI cannot produce a result.
///
/// Extends [LlmApiException] so `SkillGenerator` falls back to
/// template generation for a missing or failing CLI exactly as it
/// does for a failing HTTP provider.
class AgentCliException extends LlmApiException {
  /// Creates an [AgentCliException].
  const AgentCliException(super.message) : super(statusCode: null);

  @override
  String toString() => 'AgentCliException: $message';
}
