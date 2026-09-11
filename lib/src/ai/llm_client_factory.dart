import 'package:http/http.dart' as http;

import 'claude_client.dart';
import 'gemini_client.dart';
import 'llm_client.dart';
import 'openai_client.dart';

/// Builds the [LlmClient] for a given provider.
abstract final class LlmClientFactory {
  /// Returns a client for [provider] configured with [apiKey] and
  /// [model].
  ///
  /// [baseUrl] retargets the OpenAI-compatible and Gemini clients at
  /// a different host; it is ignored for Anthropic, whose endpoint is
  /// fixed. An optional [httpClient] can be injected for testing.
  static LlmClient create({
    required LlmProvider provider,
    required String apiKey,
    required String model,
    String? baseUrl,
    http.Client? httpClient,
  }) {
    return switch (provider) {
      LlmProvider.anthropic => ClaudeClient(
        apiKey: apiKey,
        model: model,
        httpClient: httpClient,
      ),
      LlmProvider.openai => OpenAiCompatibleClient(
        apiKey: apiKey,
        model: model,
        baseUrl: baseUrl,
        httpClient: httpClient,
      ),
      LlmProvider.gemini => GeminiClient(
        apiKey: apiKey,
        model: model,
        baseUrl: baseUrl,
        httpClient: httpClient,
      ),
    };
  }
}
