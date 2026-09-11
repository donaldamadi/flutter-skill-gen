import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_skill_gen/src/ai/llm_client.dart';
import 'package:flutter_skill_gen/src/cli/provider_options.dart';
import 'package:flutter_skill_gen/src/config/config_manager.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late ConfigManager config;
  late ArgParser parser;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'flutter_skill_gen_provider_opts_test_',
    );
    config = ConfigManager(configDir: tempDir.path, environment: const {});
    parser = ArgParser()..addOption('model', abbr: 'm');
    addProviderOptions(parser);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  ResolvedProvider resolve(List<String> args) =>
      resolveProvider(parser.parse(args), config);

  group('resolveProvider', () {
    test('falls back to the stored provider and model', () {
      config
        ..setProvider(LlmProvider.gemini)
        ..setModel('gemini-custom')
        ..setApiKey('AIza-key');

      final resolved = resolve([]);
      expect(resolved.provider, LlmProvider.gemini);
      expect(resolved.model, 'gemini-custom');
      expect(resolved.apiKey, 'AIza-key');
    });

    test('--provider overrides the stored provider', () {
      config.setProvider(LlmProvider.anthropic);

      expect(resolve(['--provider', 'openai']).provider, LlmProvider.openai);
    });

    test('--provider without --model uses that provider default, not the '
        'stored model from another vendor', () {
      config
        ..setProvider(LlmProvider.anthropic)
        ..setModel('claude-opus-5');

      final resolved = resolve(['--provider', 'gemini']);
      expect(resolved.model, ConfigManager.defaultModelFor(LlmProvider.gemini));
      expect(resolved.model, isNot('claude-opus-5'));
    });

    test('--provider keeps the stored model when it matches the stored '
        'provider', () {
      config
        ..setProvider(LlmProvider.openai)
        ..setModel('deepseek-chat');

      expect(resolve(['--provider', 'openai']).model, 'deepseek-chat');
    });

    test('--model always wins', () {
      config.setProvider(LlmProvider.anthropic);

      final resolved = resolve(['--provider', 'gemini', '-m', 'gemini-pinned']);
      expect(resolved.model, 'gemini-pinned');
    });

    test('model aliases resolve only for anthropic', () {
      expect(resolve(['-m', 'opus']).model, 'claude-opus-5');
      expect(resolve(['--provider', 'openai', '-m', 'opus']).model, 'opus');
    });

    test('picks up the key for the overridden provider', () {
      config
        ..setApiKey('sk-ant-key', target: LlmProvider.anthropic)
        ..setApiKey('sk-openai-key', target: LlmProvider.openai);

      expect(resolve(['--provider', 'openai']).apiKey, 'sk-openai-key');
      expect(resolve([]).apiKey, 'sk-ant-key');
    });

    test('--base-url overrides the stored base URL', () {
      config.setBaseUrl('https://stored.example/v1');

      expect(resolve([]).baseUrl, 'https://stored.example/v1');
      expect(
        resolve(['--base-url', 'https://flag.example/v1']).baseUrl,
        'https://flag.example/v1',
      );
    });

    test('throws on an unknown provider', () {
      expect(
        () => resolve(['--provider', 'cohere']),
        throwsA(isA<UnknownProviderException>()),
      );
    });
  });
}
