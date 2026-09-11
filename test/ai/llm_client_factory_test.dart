import 'package:flutter_skill_gen/src/ai/claude_client.dart';
import 'package:flutter_skill_gen/src/ai/gemini_client.dart';
import 'package:flutter_skill_gen/src/ai/llm_client.dart';
import 'package:flutter_skill_gen/src/ai/llm_client_factory.dart';
import 'package:flutter_skill_gen/src/ai/openai_client.dart';
import 'package:test/test.dart';

void main() {
  group('LlmProvider', () {
    test('parses canonical ids', () {
      expect(LlmProvider.tryParse('anthropic'), LlmProvider.anthropic);
      expect(LlmProvider.tryParse('openai'), LlmProvider.openai);
      expect(LlmProvider.tryParse('gemini'), LlmProvider.gemini);
    });

    test('parses aliases for compatible providers', () {
      expect(LlmProvider.tryParse('claude'), LlmProvider.anthropic);
      expect(LlmProvider.tryParse('deepseek'), LlmProvider.openai);
      expect(LlmProvider.tryParse('ollama'), LlmProvider.openai);
      expect(LlmProvider.tryParse('openai-compatible'), LlmProvider.openai);
      expect(LlmProvider.tryParse('google'), LlmProvider.gemini);
    });

    test('is case- and whitespace-insensitive', () {
      expect(LlmProvider.tryParse('  GEMINI '), LlmProvider.gemini);
    });

    test('returns null for an unknown provider', () {
      expect(LlmProvider.tryParse('cohere'), isNull);
    });
  });

  group('LlmClientFactory', () {
    LlmClient build(LlmProvider provider, {String? baseUrl}) =>
        LlmClientFactory.create(
          provider: provider,
          apiKey: 'k',
          model: 'm',
          baseUrl: baseUrl,
        );

    test('builds the client matching the provider', () {
      expect(build(LlmProvider.anthropic), isA<ClaudeClient>());
      expect(build(LlmProvider.openai), isA<OpenAiCompatibleClient>());
      expect(build(LlmProvider.gemini), isA<GeminiClient>());
    });

    test('passes baseUrl through to the OpenAI-compatible client', () {
      final client =
          build(LlmProvider.openai, baseUrl: 'https://api.groq.com/openai/v1')
              as OpenAiCompatibleClient;
      expect(client.baseUrl, 'https://api.groq.com/openai/v1');
    });

    test('falls back to each provider default when baseUrl is null', () {
      expect(
        (build(LlmProvider.openai) as OpenAiCompatibleClient).baseUrl,
        OpenAiCompatibleClient.defaultBaseUrl,
      );
      expect(
        (build(LlmProvider.gemini) as GeminiClient).baseUrl,
        GeminiClient.defaultBaseUrl,
      );
    });
  });
}
