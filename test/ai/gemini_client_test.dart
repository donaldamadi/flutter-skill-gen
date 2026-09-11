import 'dart:convert';

import 'package:flutter_skill_gen/src/ai/gemini_client.dart';
import 'package:flutter_skill_gen/src/ai/llm_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:test/test.dart';

http_testing.MockClient _respond(Object body, [int status = 200]) {
  return http_testing.MockClient(
    (_) async => http.Response(jsonEncode(body), status),
  );
}

Object _reply(List<Object> parts, {String finishReason = 'STOP'}) => {
  'candidates': [
    {
      'finishReason': finishReason,
      'content': {'role': 'model', 'parts': parts},
    },
  ],
};

void main() {
  group('GeminiClient', () {
    test('sends a generateContent request with the key header', () async {
      late Uri capturedUri;
      late Map<String, String> capturedHeaders;
      late Map<String, dynamic> capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(
            _reply([
              {'text': 'ok'},
            ]),
          ),
          200,
        );
      });

      final client = GeminiClient(
        apiKey: 'AIza-test',
        model: 'gemini-test',
        httpClient: mockClient,
      );

      await client.complete(systemPrompt: 'sys', userMessage: 'usr');

      expect(
        capturedUri.toString(),
        'https://generativelanguage.googleapis.com/v1beta/'
        'models/gemini-test:generateContent',
      );
      expect(capturedHeaders['x-goog-api-key'], 'AIza-test');

      // Gemini takes the system prompt in a dedicated field, and the
      // model is in the URL rather than the body.
      final systemInstruction =
          capturedBody['systemInstruction'] as Map<String, dynamic>;
      final systemParts = systemInstruction['parts'] as List<dynamic>;
      expect((systemParts.first as Map)['text'], 'sys');

      final contents = capturedBody['contents'] as List<dynamic>;
      final userParts = (contents.first as Map)['parts'] as List<dynamic>;
      expect((userParts.first as Map)['text'], 'usr');

      final generationConfig =
          capturedBody['generationConfig'] as Map<String, dynamic>;
      expect(generationConfig['maxOutputTokens'], 16000);

      client.close();
    });

    test('returns the candidate text', () async {
      final client = GeminiClient(
        apiKey: 'AIza',
        model: 'm',
        httpClient: _respond(
          _reply([
            {'text': '# My Project'},
          ]),
        ),
      );

      final result = await client.complete(
        systemPrompt: 'sys',
        userMessage: 'usr',
      );

      expect(result, '# My Project');

      client.close();
    });

    test('skips thought parts and joins the rest', () async {
      final client = GeminiClient(
        apiKey: 'AIza',
        model: 'm',
        httpClient: _respond(
          _reply([
            {'text': 'internal reasoning', 'thought': true},
            {'text': 'part one\n'},
            {'text': 'part two'},
          ]),
        ),
      );

      final result = await client.complete(
        systemPrompt: 'sys',
        userMessage: 'usr',
      );

      expect(result, 'part one\npart two');

      client.close();
    });

    test('throws LlmApiException on non-200 status', () {
      final client = GeminiClient(
        apiKey: 'AIza-bad',
        model: 'm',
        httpClient: _respond({
          'error': {'message': 'API key not valid'},
        }, 400),
      );

      expect(
        () => client.complete(systemPrompt: 'sys', userMessage: 'usr'),
        throwsA(
          isA<LlmApiException>().having((e) => e.statusCode, 'statusCode', 400),
        ),
      );

      client.close();
    });

    test('surfaces a blocked prompt', () {
      final client = GeminiClient(
        apiKey: 'AIza',
        model: 'm',
        httpClient: _respond({
          'promptFeedback': {'blockReason': 'SAFETY'},
        }),
      );

      expect(
        () => client.complete(systemPrompt: 'sys', userMessage: 'usr'),
        throwsA(
          isA<LlmApiException>().having(
            (e) => e.message,
            'message',
            contains('SAFETY'),
          ),
        ),
      );

      client.close();
    });

    test('reports a MAX_TOKENS truncation', () {
      final client = GeminiClient(
        apiKey: 'AIza',
        model: 'm',
        httpClient: _respond(_reply([], finishReason: 'MAX_TOKENS')),
      );

      expect(
        () => client.complete(systemPrompt: 'sys', userMessage: 'usr'),
        throwsA(
          isA<LlmApiException>().having(
            (e) => e.message,
            'message',
            contains('token limit'),
          ),
        ),
      );

      client.close();
    });

    test('throws LlmApiException on no candidates', () {
      final client = GeminiClient(
        apiKey: 'AIza',
        model: 'm',
        httpClient: _respond({'candidates': <dynamic>[]}),
      );

      expect(
        () => client.complete(systemPrompt: 'sys', userMessage: 'usr'),
        throwsA(isA<LlmApiException>()),
      );

      client.close();
    });

    test('throws LlmApiException on network error', () {
      final client = GeminiClient(
        apiKey: 'AIza',
        model: 'm',
        httpClient: http_testing.MockClient(
          (_) => throw Exception('Connection refused'),
        ),
      );

      expect(
        () => client.complete(systemPrompt: 'sys', userMessage: 'usr'),
        throwsA(
          isA<LlmApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            isNull,
          ),
        ),
      );

      client.close();
    });
  });
}
