import 'package:http/http.dart' as http;

import 'agent_cli_client.dart';
import 'claude_client.dart';
import 'gemini_client.dart';
import 'llm_client.dart';
import 'openai_client.dart';

/// Builds the [LlmClient] for a given provider.
abstract final class LlmClientFactory {
  /// Returns a client for [provider] configured with [apiKey] and
  /// [model].
  ///
  /// [apiKey] may be `null` only for providers whose
  /// `requiresApiKey` is `false` — passing `null` for any other
  /// provider throws [MissingApiKeyException].
  ///
  /// [baseUrl] retargets the OpenAI-compatible and Gemini clients at
  /// a different host; it is ignored for Anthropic, whose endpoint is
  /// fixed, and for Claude Code, which manages its own endpoint. An
  /// optional [httpClient] can be injected for testing.
  static LlmClient create({
    required LlmProvider provider,
    required String? apiKey,
    required String model,
    String? baseUrl,
    http.Client? httpClient,
    Map<String, String>? environment,
  }) {
    if (provider.requiresApiKey && (apiKey == null || apiKey.isEmpty)) {
      throw MissingApiKeyException(provider);
    }

    return switch (provider) {
      LlmProvider.anthropic => ClaudeClient(
        apiKey: apiKey!,
        model: model,
        httpClient: httpClient,
      ),
      LlmProvider.openai => OpenAiCompatibleClient(
        apiKey: apiKey!,
        model: model,
        baseUrl: baseUrl,
        httpClient: httpClient,
      ),
      LlmProvider.gemini => GeminiClient(
        apiKey: apiKey!,
        model: model,
        baseUrl: baseUrl,
        httpClient: httpClient,
      ),
      LlmProvider.claudeCode => _agentClient(
        AgentCli.claudeCode,
        model,
        environment,
      ),
      LlmProvider.codex => _agentClient(AgentCli.codex, model, environment),
      LlmProvider.geminiCli => _agentClient(
        AgentCli.geminiCli,
        model,
        environment,
      ),
    };
  }

  /// Builds a client for a locally installed agent CLI.
  static AgentCliClient _agentClient(
    AgentCli agent,
    String model,
    Map<String, String>? environment,
  ) => AgentCliClient(
    agent: agent,
    model: model,
    executable: AgentCliClient.resolveExecutable(agent, environment),
  );
}

/// Thrown when a provider that needs an API key is asked to build a
/// client without one.
class MissingApiKeyException extends LlmApiException {
  /// Creates a [MissingApiKeyException] for [provider].
  MissingApiKeyException(this.provider)
    : super(
        'No API key configured for provider "${provider.id}". '
        'Set one with: flutter_skill_gen config --set-provider '
        '${provider.id} --set-key <key>',
      );

  /// The provider that was missing a key.
  final LlmProvider provider;

  @override
  String toString() => 'MissingApiKeyException: $message';
}
