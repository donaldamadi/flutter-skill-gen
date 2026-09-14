/// Provider-agnostic interface for the chat-completion call that
/// drives skill generation.
///
/// Implementations wrap a single vendor's HTTP API and normalise it
/// to one method, so `SkillGenerator` never needs to know which
/// provider is in play.
abstract class LlmClient {
  /// Sends [systemPrompt] and [userMessage] to the provider and
  /// returns the assistant's text.
  ///
  /// Throws [LlmApiException] on non-success responses, network
  /// errors, refusals, and responses that carry no usable text.
  Future<String> complete({
    required String systemPrompt,
    required String userMessage,
    int maxTokens,
  });

  /// Closes the underlying HTTP client.
  void close();
}

/// The LLM providers this tool can talk to.
enum LlmProvider {
  /// Anthropic's Messages API (`api.anthropic.com`).
  anthropic('anthropic'),

  /// Any endpoint speaking OpenAI's `/chat/completions` shape —
  /// OpenAI itself, DeepSeek, Groq, Together, Fireworks, OpenRouter,
  /// Ollama, vLLM, and friends.
  openai('openai'),

  /// Google's Gemini `generateContent` API.
  gemini('gemini'),

  /// The locally installed `claude` CLI, driven in print mode.
  ///
  /// Authenticates with whatever credentials Claude Code already
  /// holds, so it needs no API key of its own.
  claudeCode('claude-code', requiresApiKey: false),

  /// The locally installed `codex` CLI, driven with `codex exec`.
  ///
  /// Uses the ChatGPT account Codex is already signed in to.
  codex('codex', requiresApiKey: false),

  /// The locally installed `gemini` CLI, driven in headless mode.
  ///
  /// Uses the Google account Gemini CLI is already signed in to, and
  /// is distinct from `gemini`, which calls the hosted API with a key.
  geminiCli('gemini-cli', requiresApiKey: false);

  const LlmProvider(this.id, {this.requiresApiKey = true});

  /// Stable identifier used in config files and on the CLI.
  final String id;

  /// Whether this provider needs an API key before it can be used.
  ///
  /// `false` for providers that carry their own credentials, which is
  /// what lets `SkillGenerator` enable AI generation without a key.
  final bool requiresApiKey;

  /// All provider ids, for help text and validation messages.
  static List<String> get all => values.map((p) => p.id).toList();

  /// Parses [input] into a provider, or returns `null` when it does
  /// not name one.
  ///
  /// Accepts a handful of aliases so `--provider openai-compatible`,
  /// `--provider deepseek`, and `--provider claude` all land on the
  /// right client.
  static LlmProvider? tryParse(String input) {
    final normalized = input.trim().toLowerCase();
    return switch (normalized) {
      'anthropic' || 'claude' => LlmProvider.anthropic,
      'openai' ||
      'openai-compatible' ||
      'deepseek' ||
      'groq' ||
      'together' ||
      'fireworks' ||
      'openrouter' ||
      'ollama' => LlmProvider.openai,
      'gemini' || 'google' => LlmProvider.gemini,
      'claude-code' ||
      'claude_code' ||
      'claudecode' ||
      'cc' => LlmProvider.claudeCode,
      'codex' || 'codex-cli' || 'codex_cli' => LlmProvider.codex,
      'gemini-cli' || 'gemini_cli' || 'geminicli' => LlmProvider.geminiCli,
      _ => null,
    };
  }
}

/// Exception thrown when a provider call fails.
///
/// Every [LlmClient] implementation reports failures as this type (or
/// a subclass), which is what lets `SkillGenerator` fall back to
/// template generation regardless of provider.
class LlmApiException implements Exception {
  /// Creates an [LlmApiException].
  const LlmApiException(this.message, {this.statusCode});

  /// Human-readable error message.
  final String message;

  /// HTTP status code, or `null` for network errors.
  final int? statusCode;

  @override
  String toString() => 'LlmApiException: $message';
}
