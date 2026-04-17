import 'dart:convert';

import 'package:flutter_skill_gen/src/ai/claude_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:test/test.dart';

void main() {
  group('ClaudeClient', () {
    group('complete', () {
      test('sends correct request to Anthropic API', () async {
        late Uri capturedUri;
        late Map<String, String> capturedHeaders;
        late Map<String, dynamic> capturedBody;

        final mockClient = http_testing.MockClient((request) async {
          capturedUri = request.url;
          capturedHeaders = request.headers;
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': 'Generated SKILL.md'},
              ],
            }),
            200,
          );
        });

        final client = ClaudeClient(
          apiKey: 'sk-ant-test-key',
          model: 'claude-sonnet-4-20250514',
          httpClient: mockClient,
        );

        await client.complete(
          systemPrompt: 'You are a helpful assistant.',
          userMessage: 'Generate a SKILL.md',
        );

        expect(capturedUri.toString(), 'https://api.anthropic.com/v1/messages');
        expect(capturedHeaders['x-api-key'], 'sk-ant-test-key');
        expect(capturedHeaders['anthropic-version'], '2023-06-01');
        expect(capturedHeaders['Content-Type'], 'application/json');
        expect(capturedBody['model'], 'claude-sonnet-4-20250514');
        expect(capturedBody['system'], 'You are a helpful assistant.');
        expect(capturedBody['max_tokens'], 8192);

        final messages = capturedBody['messages'] as List<dynamic>;
        expect(messages, hasLength(1));
        final msg = messages.first as Map<String, dynamic>;
        expect(msg['role'], 'user');
        expect(msg['content'], 'Generate a SKILL.md');

        client.close();
      });

      test('returns text from API response', () async {
        final mockClient = http_testing.MockClient(
          (_) async => http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': '# My Project\n\nGenerated content.'},
              ],
            }),
            200,
          ),
        );

        final client = ClaudeClient(apiKey: 'sk-test', httpClient: mockClient);

        final result = await client.complete(
          systemPrompt: 'system',
          userMessage: 'user',
        );

        expect(result, '# My Project\n\nGenerated content.');

        client.close();
      });

      test('throws ClaudeApiException on non-200 status', () {
        final mockClient = http_testing.MockClient(
          (_) async =>
              http.Response('{"error": {"message": "Invalid API key"}}', 401),
        );

        final client = ClaudeClient(
          apiKey: 'sk-bad-key',
          httpClient: mockClient,
        );

        expect(
          () => client.complete(systemPrompt: 'system', userMessage: 'user'),
          throwsA(
            isA<ClaudeApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              401,
            ),
          ),
        );

        client.close();
      });

      test('throws ClaudeApiException on empty content', () {
        final mockClient = http_testing.MockClient(
          (_) async => http.Response(jsonEncode({'content': <dynamic>[]}), 200),
        );

        final client = ClaudeClient(apiKey: 'sk-test', httpClient: mockClient);

        expect(
          () => client.complete(systemPrompt: 'system', userMessage: 'user'),
          throwsA(
            isA<ClaudeApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              200,
            ),
          ),
        );

        client.close();
      });

      test('throws ClaudeApiException on network error', () {
        final mockClient = http_testing.MockClient(
          (_) => throw Exception('Connection refused'),
        );

        final client = ClaudeClient(apiKey: 'sk-test', httpClient: mockClient);

        expect(
          () => client.complete(systemPrompt: 'system', userMessage: 'user'),
          throwsA(
            isA<ClaudeApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              isNull,
            ),
          ),
        );

        client.close();
      });

      test('respects custom maxTokens', () async {
        late Map<String, dynamic> capturedBody;

        final mockClient = http_testing.MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': 'ok'},
              ],
            }),
            200,
          );
        });

        final client = ClaudeClient(apiKey: 'sk-test', httpClient: mockClient);

        await client.complete(
          systemPrompt: 'system',
          userMessage: 'user',
          maxTokens: 4096,
        );

        expect(capturedBody['max_tokens'], 4096);

        client.close();
      });
    });

    group('ClaudeApiException', () {
      test('toString includes message', () {
        const e = ClaudeApiException('Something went wrong', statusCode: 500);
        expect(e.toString(), 'ClaudeApiException: Something went wrong');
      });

      test('statusCode can be null for network errors', () {
        const e = ClaudeApiException('Network error');
        expect(e.statusCode, isNull);
      });
    });
  });
}
