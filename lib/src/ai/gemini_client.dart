import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_client.dart';

/// HTTP client for Google's Gemini `generateContent` API.
///
/// Gemini differs from both other providers: the system prompt is a
/// dedicated `systemInstruction` field, the reply arrives as a list
/// of `parts`, and blocking shows up as a `finishReason` rather than
/// an HTTP error.
class GeminiClient implements LlmClient {
  /// Creates a [GeminiClient] with the given [apiKey] and [model].
  GeminiClient({
    required this.apiKey,
    required this.model,
    String? baseUrl,
    http.Client? httpClient,
  }) : baseUrl = _normalizeBaseUrl(baseUrl ?? defaultBaseUrl),
       _http = httpClient ?? http.Client();

  /// The Google AI Studio API key.
  final String apiKey;

  /// The Gemini model ID to use.
  final String model;

  /// API root, without a trailing slash.
  final String baseUrl;

  final http.Client _http;

  /// API root used when none is configured.
  static const defaultBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  static String _normalizeBaseUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Sends a prompt to Gemini and returns the text response.
  ///
  /// Throws [LlmApiException] on non-200 responses or network errors.
  @override
  Future<String> complete({
    required String systemPrompt,
    required String userMessage,
    int maxTokens = 16000,
  }) async {
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': userMessage},
          ],
        },
      ],
      'generationConfig': {'maxOutputTokens': maxTokens},
    });

    final http.Response response;
    try {
      response = await _http.post(
        Uri.parse('$baseUrl/models/$model:generateContent'),
        headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
        body: body,
      );
    } on Exception catch (e) {
      throw LlmApiException('Network error: $e', statusCode: null);
    }

    if (response.statusCode != 200) {
      throw LlmApiException(
        'API returned ${response.statusCode}: '
        '${response.body}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    // A blocked prompt returns 200 with no candidates at all.
    final feedback = json['promptFeedback'] as Map<String, dynamic>?;
    final blockReason = feedback?['blockReason'];
    if (blockReason is String && blockReason.isNotEmpty) {
      throw LlmApiException(
        'Prompt blocked by Gemini (reason: $blockReason)',
        statusCode: 200,
      );
    }

    final candidates = json['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw const LlmApiException('Empty response from API', statusCode: 200);
    }

    final candidate = candidates.first as Map<String, dynamic>;
    final finishReason = candidate['finishReason'] as String?;
    final content = candidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? const [];

    // Thinking models return their reasoning as parts flagged
    // `thought: true`; those carry no answer text and must be
    // skipped rather than concatenated into the skill.
    final buffer = StringBuffer();
    for (final part in parts.cast<Map<String, dynamic>>()) {
      if (part['thought'] == true) continue;
      final text = part['text'];
      if (text is String) buffer.write(text);
    }

    if (buffer.isEmpty) {
      throw LlmApiException(switch (finishReason) {
        'MAX_TOKENS' =>
          'Response hit the $maxTokens token limit before any text '
              'was produced. Retry with a higher max_tokens.',
        'SAFETY' || 'PROHIBITED_CONTENT' =>
          'Gemini blocked the response (finishReason: $finishReason)',
        _ =>
          'Response contained no text (finishReason: '
              '${finishReason ?? 'unknown'})',
      }, statusCode: 200);
    }

    return buffer.toString();
  }

  /// Closes the underlying HTTP client.
  @override
  void close() => _http.close();
}
