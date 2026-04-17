import 'dart:convert';

import 'package:http/http.dart' as http;

/// Lightweight HTTP client for the Anthropic Messages API.
class ClaudeClient {
  /// Creates a [ClaudeClient] with the given [apiKey] and optional
  /// [model] override.
  ClaudeClient({
    required this.apiKey,
    this.model = 'claude-sonnet-4-20250514',
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
  Future<String> complete({
    required String systemPrompt,
    required String userMessage,
    int maxTokens = 8192,
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
    final content = json['content'] as List<dynamic>;
    if (content.isEmpty) {
      throw const ClaudeApiException(
        'Empty response from API',
        statusCode: 200,
      );
    }

    final firstBlock = content.first as Map<String, dynamic>;
    return firstBlock['text'] as String;
  }

  /// Closes the underlying HTTP client.
  void close() => _http.close();
}

/// Exception thrown when the Claude API returns an error.
class ClaudeApiException implements Exception {
  /// Creates a [ClaudeApiException].
  const ClaudeApiException(this.message, {this.statusCode});

  /// Human-readable error message.
  final String message;

  /// HTTP status code, or `null` for network errors.
  final int? statusCode;

  @override
  String toString() => 'ClaudeApiException: $message';
}
