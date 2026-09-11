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
  gemini('gemini');

  const LlmProvider(this.id);

  /// Stable identifier used in config files and on the CLI.
  final String id;

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
