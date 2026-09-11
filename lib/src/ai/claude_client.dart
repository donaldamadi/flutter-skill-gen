import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_client.dart';

/// Lightweight HTTP client for the Anthropic Messages API.
class ClaudeClient implements LlmClient {
  /// Creates a [ClaudeClient] with the given [apiKey] and optional
  /// [model] override.
  ClaudeClient({
    required this.apiKey,
    this.model = 'claude-sonnet-5',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// The Anthropic API key.
  final String apiKey;

  /// The Claude model ID to use.
  final String model;

  final http.Client _http;

  static const _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const _apiVersion = '2023-06-01';

  /// Sends a prompt to Claude and returns the text response.
  ///
  /// Throws [ClaudeApiException] on non-200 responses or network
  /// errors.
  @override
  Future<String> complete({
    required String systemPrompt,
    required String userMessage,
    int maxTokens = 16000,
  }) async {
    final body = jsonEncode({
      'model': model,
      'max_tokens': maxTokens,
      'system': systemPrompt,
      'messages': [
        {'role': 'user', 'content': userMessage},
      ],
    });

    final http.Response response;
    try {
      response = await _http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': _apiVersion,
        },
        body: body,
      );
    } on Exception catch (e) {
      throw ClaudeApiException('Network error: $e', statusCode: null);
    }

    if (response.statusCode != 200) {
      throw ClaudeApiException(
        'API returned ${response.statusCode}: '
        '${response.body}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final stopReason = json['stop_reason'] as String?;
    if (stopReason == 'refusal') {
      final details = json['stop_details'] as Map<String, dynamic>?;
      throw ClaudeApiException(
        'Model declined the request '
        '(category: ${details?['category'] ?? 'unknown'})',
        statusCode: 200,
      );
    }

    final content = json['content'] as List<dynamic>;
    if (content.isEmpty) {
      throw const ClaudeApiException(
        'Empty response from API',
        statusCode: 200,
      );
    }

    // Models with thinking enabled (Sonnet 5, Opus 5, ...) put a
    // `thinking` block first, so the text has to be collected by
    // block type rather than taken from `content.first`.
    final buffer = StringBuffer();
    for (final block in content.cast<Map<String, dynamic>>()) {
      if (block['type'] != 'text') continue;
      final text = block['text'];
      if (text is String) buffer.write(text);
    }

    if (buffer.isEmpty) {
      final types = content
          .cast<Map<String, dynamic>>()
          .map((b) => b['type'])
          .join(', ');
      throw ClaudeApiException(
        stopReason == 'max_tokens'
            ? 'Response hit the $maxTokens token limit before any text '
                  'was produced (blocks: $types). Retry with a higher '
                  'max_tokens.'
            : 'Response contained no text blocks (blocks: $types)',
        statusCode: 200,
      );
    }

    return buffer.toString();
  }

  /// Closes the underlying HTTP client.
  @override
  void close() => _http.close();
}

/// Exception thrown when the Claude API returns an error.
///
/// Extends [LlmApiException] so provider-agnostic callers can catch
/// every provider's failures uniformly.
class ClaudeApiException extends LlmApiException {
  /// Creates a [ClaudeApiException].
  const ClaudeApiException(super.message, {super.statusCode});

  @override
  String toString() => 'ClaudeApiException: $message';
}
