import 'dart:convert';

import 'package:flutter_skill_gen/src/ai/llm_client.dart';
import 'package:flutter_skill_gen/src/ai/openai_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:test/test.dart';

http_testing.MockClient _respond(Object body, [int status = 200]) {
  return http_testing.MockClient(
    (_) async => http.Response(jsonEncode(body), status),
  );
}

Object _reply(String text, {String finishReason = 'stop'}) => {
  'choices': [
    {
      'finish_reason': finishReason,
      'message': {'role': 'assistant', 'content': text},
    },
  ],
};

void main() {
  group('OpenAiCompatibleClient', () {
    test('sends an OpenAI-shaped request with a bearer token', () async {
      late Uri capturedUri;
      late Map<String, String> capturedHeaders;
      late Map<String, dynamic> capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_reply('ok')), 200);
      });

      final client = OpenAiCompatibleClient(
        apiKey: 'sk-test-key',
        model: 'some-model',
        httpClient: mockClient,
      );

      await client.complete(systemPrompt: 'sys', userMessage: 'usr');

      expect(
        capturedUri.toString(),
        'https://api.openai.com/v1/chat/completions',
      );
      expect(capturedHeaders['Authorization'], 'Bearer sk-test-key');
      expect(capturedBody['model'], 'some-model');
      expect(capturedBody['max_tokens'], 16000);

      // The system prompt is a message role here, not a top-level field.
      expect(capturedBody.containsKey('system'), isFalse);
      final messages = capturedBody['messages'] as List<dynamic>;
      expect(messages, hasLength(2));
      expect((messages[0] as Map)['role'], 'system');
      expect((messages[0] as Map)['content'], 'sys');
      expect((messages[1] as Map)['role'], 'user');
      expect((messages[1] as Map)['content'], 'usr');

      client.close();
    });

    test('returns the assistant message content', () async {
      final client = OpenAiCompatibleClient(
        apiKey: 'sk-test',
        model: 'm',
        httpClient: _respond(_reply('# My Project')),
      );

      final result = await client.complete(
        systemPrompt: 'sys',
        userMessage: 'usr',
      );

      expect(result, '# My Project');

      client.close();
    });

    test('retargets at a compatible provider via baseUrl', () async {
      late Uri capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode(_reply('ok')), 200);
      });

      final client = OpenAiCompatibleClient(
        apiKey: 'sk-test',
        model: 'deepseek-chat',
        // Trailing slash must not produce a doubled path separator.
        baseUrl: 'https://api.deepseek.com/v1/',
        httpClient: mockClient,
      );

      await client.complete(systemPrompt: 'sys', userMessage: 'usr');

      expect(
        capturedUri.toString(),
        'https://api.deepseek.com/v1/chat/completions',
      );

      client.close();
    });

    test('retries with max_completion_tokens when told to', () async {
      final tokenFields = <String>[];

      final mockClient = http_testing.MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body.containsKey('max_tokens')) {
          tokenFields.add('max_tokens');
          return http.Response(
            jsonEncode({
              'error': {
                'message':
                    "Unsupported parameter: 'max_tokens' is not supported "
                    "with this model. Use 'max_completion_tokens' instead.",
              },
            }),
            400,
          );
        }
        tokenFields.add('max_completion_tokens');
        return http.Response(jsonEncode(_reply('ok')), 200);
      });

      final client = OpenAiCompatibleClient(
        apiKey: 'sk-test',
        model: 'reasoning-model',
        httpClient: mockClient,
      );

      final result = await client.complete(
        systemPrompt: 'sys',
        userMessage: 'usr',
      );

      expect(result, 'ok');
      expect(tokenFields, ['max_tokens', 'max_completion_tokens']);

      client.close();
    });

    test('does not retry a 400 that is unrelated to the token field', () async {
      var calls = 0;

      final mockClient = http_testing.MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({
            'error': {'message': 'model not found'},
          }),
          400,
        );
      });

      final client = OpenAiCompatibleClient(
        apiKey: 'sk-test',
        model: 'nope',
        httpClient: mockClient,
      );

      await expectLater(
        client.complete(systemPrompt: 'sys', userMessage: 'usr'),
        throwsA(isA<LlmApiException>()),
      );
      expect(calls, 1);

      client.close();
    });

    test('throws LlmApiException on non-200 status', () {
      final client = OpenAiCompatibleClient(
        apiKey: 'sk-bad',
        model: 'm',
        httpClient: _respond({
          'error': {'message': 'Invalid API key'},
        }, 401),
      );

      expect(
        () => client.complete(systemPrompt: 'sys', userMessage: 'usr'),
        throwsA(
          isA<LlmApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );

      client.close();
    });

    test('surfaces a refusal', () {
      final client = OpenAiCompatibleClient(
        apiKey: 'sk-test',
        model: 'm',
        httpClient: _respond({
          'choices': [
            {
              'finish_reason': 'stop',
              'message': {'content': null, 'refusal': 'I cannot help'},
            },
          ],
        }),
      );

      expect(
        () => client.complete(systemPrompt: 'sys', userMessage: 'usr'),
        throwsA(
          isA<LlmApiException>().having(
            (e) => e.message,
            'message',
            contains('I cannot help'),
          ),
        ),
      );

      client.close();
    });

    test('reports a length-truncated empty response', () {
      final client = OpenAiCompatibleClient(
        apiKey: 'sk-test',
        model: 'm',
        httpClient: _respond(_reply('', finishReason: 'length')),
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

    test('throws LlmApiException on empty choices', () {
      final client = OpenAiCompatibleClient(
        apiKey: 'sk-test',
        model: 'm',
        httpClient: _respond({'choices': <dynamic>[]}),
      );

      expect(
        () => client.complete(systemPrompt: 'sys', userMessage: 'usr'),
        throwsA(isA<LlmApiException>()),
      );

      client.close();
    });

    test('throws LlmApiException on network error', () {
      final client = OpenAiCompatibleClient(
        apiKey: 'sk-test',
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
