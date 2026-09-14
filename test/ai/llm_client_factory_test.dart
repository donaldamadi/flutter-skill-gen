import 'package:flutter_skill_gen/src/ai/agent_cli_client.dart';
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

    test('parses the claude-code aliases', () {
      for (final alias in ['claude-code', 'claude_code', 'claudecode', 'cc']) {
        expect(
          LlmProvider.tryParse(alias),
          LlmProvider.claudeCode,
          reason: 'alias "\$alias" should name the Claude Code provider',
        );
      }
    });

    test('keeps "claude" pointing at the Anthropic API', () {
      // "claude" has meant the hosted API since before the CLI
      // provider existed; repointing it would silently change which
      // account a user's runs are billed to.
      expect(LlmProvider.tryParse('claude'), LlmProvider.anthropic);
    });

    test('only the agent-CLI providers carry their own credentials', () {
      expect(LlmProvider.claudeCode.requiresApiKey, isFalse);
      expect(LlmProvider.codex.requiresApiKey, isFalse);
      expect(LlmProvider.geminiCli.requiresApiKey, isFalse);
      expect(LlmProvider.anthropic.requiresApiKey, isTrue);
      expect(LlmProvider.openai.requiresApiKey, isTrue);
      expect(LlmProvider.gemini.requiresApiKey, isTrue);
    });

    test('parses the codex and gemini-cli aliases', () {
      expect(LlmProvider.tryParse('codex'), LlmProvider.codex);
      expect(LlmProvider.tryParse('codex-cli'), LlmProvider.codex);
      expect(LlmProvider.tryParse('gemini-cli'), LlmProvider.geminiCli);
      expect(LlmProvider.tryParse('gemini_cli'), LlmProvider.geminiCli);
    });

    test('keeps "gemini" pointing at the hosted API', () {
      // gemini-cli drives the local binary; gemini calls the paid API.
      // Confusing the two would change who gets billed.
      expect(LlmProvider.tryParse('gemini'), LlmProvider.gemini);
      expect(LlmProvider.tryParse('google'), LlmProvider.gemini);
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
      expect(build(LlmProvider.claudeCode), isA<AgentCliClient>());
      expect(build(LlmProvider.codex), isA<AgentCliClient>());
      expect(build(LlmProvider.geminiCli), isA<AgentCliClient>());
    });

    test('builds the Claude Code client with no key at all', () {
      final client = LlmClientFactory.create(
        provider: LlmProvider.claudeCode,
        apiKey: null,
        model: 'sonnet',
      );

      expect(client, isA<AgentCliClient>());
      expect((client as AgentCliClient).model, 'sonnet');
      expect(client.agent, AgentCli.claudeCode);
    });

    test('refuses to build a key-requiring client without a key', () {
      for (final provider in LlmProvider.values.where(
        (p) => p.requiresApiKey,
      )) {
        expect(
          () => LlmClientFactory.create(
            provider: provider,
            apiKey: null,
            model: 'm',
          ),
          throwsA(isA<MissingApiKeyException>()),
          reason: '\${provider.id} needs a key',
        );
      }
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
