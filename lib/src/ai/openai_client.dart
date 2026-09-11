import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_client.dart';

/// HTTP client for any endpoint that speaks OpenAI's
/// `/chat/completions` shape.
///
/// Defaults to OpenAI itself, but [baseUrl] retargets it at any
/// compatible provider — DeepSeek, Groq, Together, Fireworks,
/// OpenRouter, or a local Ollama/vLLM server.
class OpenAiCompatibleClient implements LlmClient {
  /// Creates an [OpenAiCompatibleClient] with the given [apiKey],
  /// [model], and optional [baseUrl] override.
  OpenAiCompatibleClient({
    required this.apiKey,
    required this.model,
    String? baseUrl,
    http.Client? httpClient,
  }) : baseUrl = _normalizeBaseUrl(baseUrl ?? defaultBaseUrl),
       _http = httpClient ?? http.Client();

  /// The provider API key, sent as a bearer token.
  final String apiKey;

  /// The model ID to request.
  final String model;

  /// API root, without a trailing slash. `/chat/completions` is
  /// appended to it.
  final String baseUrl;

  final http.Client _http;

  /// API root used when none is configured.
  static const defaultBaseUrl = 'https://api.openai.com/v1';

  static String _normalizeBaseUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Sends a prompt to the provider and returns the text response.
  ///
  /// Throws [LlmApiException] on non-200 responses or network errors.
  @override
  Future<String> complete({
    required String systemPrompt,
    required String userMessage,
    int maxTokens = 16000,
  }) async {
    var response = await _post(
      systemPrompt: systemPrompt,
      userMessage: userMessage,
      maxTokens: maxTokens,
      tokenField: 'max_tokens',
    );

    // OpenAI's reasoning models reject `max_tokens` and name the
    // field they want in the error. Other compatible providers only
    // understand `max_tokens`, so ask for the alternative only when
    // told to.
    if (response.statusCode == 400 &&
        response.body.contains('max_completion_tokens')) {
      response = await _post(
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        maxTokens: maxTokens,
        tokenField: 'max_completion_tokens',
      );
    }

    if (response.statusCode != 200) {
      throw LlmApiException(
        'API returned ${response.statusCode}: '
        '${response.body}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw const LlmApiException('Empty response from API', statusCode: 200);
    }

    final choice = choices.first as Map<String, dynamic>;
    final message = choice['message'] as Map<String, dynamic>?;
    final finishReason = choice['finish_reason'] as String?;

    final refusal = message?['refusal'];
    if (refusal is String && refusal.isNotEmpty) {
      throw LlmApiException(
        'Model declined the request: $refusal',
        statusCode: 200,
      );
    }

    final content = message?['content'];
    if (content is! String || content.isEmpty) {
      throw LlmApiException(
        finishReason == 'length'
            ? 'Response hit the $maxTokens token limit before any text '
                  'was produced. Retry with a higher max_tokens.'
            : 'Response contained no text (finish_reason: '
                  '${finishReason ?? 'unknown'})',
        statusCode: 200,
      );
    }

    return content;
  }

  Future<http.Response> _post({
    required String systemPrompt,
    required String userMessage,
    required int maxTokens,
    required String tokenField,
  }) async {
    final body = jsonEncode({
      'model': model,
      tokenField: maxTokens,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userMessage},
      ],
    });

    try {
      return await _http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: body,
      );
    } on Exception catch (e) {
      throw LlmApiException('Network error: $e', statusCode: null);
    }
  }

  /// Closes the underlying HTTP client.
  @override
  void close() => _http.close();
}
