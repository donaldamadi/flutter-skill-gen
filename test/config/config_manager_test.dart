import 'dart:io';

import 'package:flutter_skill_gen/src/ai/llm_client.dart';
import 'package:flutter_skill_gen/src/config/config_manager.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late ConfigManager config;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'flutter_skill_gen_config_test_',
    );
    config = ConfigManager(configDir: tempDir.path, environment: const {});
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ConfigManager', () {
    test('read returns empty map when no config exists', () {
      expect(config.read(), isEmpty);
    });

    test('apiKey is null when not configured', () {
      expect(config.apiKey, isNull);
    });

    test('hasApiKey is false when not configured', () {
      expect(config.hasApiKey, isFalse);
    });

    test('model returns default when not configured', () {
      expect(config.model, 'claude-sonnet-5');
    });

    test('configPath points to config.yaml in configDir', () {
      expect(config.configPath, endsWith('config.yaml'));
      expect(config.configPath, contains(tempDir.path));
    });

    group('setApiKey / apiKey', () {
      test('stores and retrieves API key', () {
        config.setApiKey('sk-ant-test-key-12345');
        expect(config.apiKey, 'sk-ant-test-key-12345');
      });

      test('hasApiKey is true after setting key', () {
        config.setApiKey('sk-ant-test-key-12345');
        expect(config.hasApiKey, isTrue);
      });

      test('creates config directory if missing', () {
        final nested = ConfigManager(configDir: '${tempDir.path}/nested/deep')
          ..setApiKey('sk-test');
        expect(nested.apiKey, 'sk-test');
        expect(Directory('${tempDir.path}/nested/deep').existsSync(), isTrue);
      });
    });

    group('removeApiKey', () {
      test('removes stored API key', () {
        config.setApiKey('sk-ant-test-key-12345');
        expect(config.hasApiKey, isTrue);

        config.removeApiKey();
        expect(config.apiKey, isNull);
        expect(config.hasApiKey, isFalse);
      });

      test('preserves other config values', () {
        config
          ..setApiKey('sk-test')
          ..setModel('claude-opus-5')
          ..removeApiKey();
        expect(config.apiKey, isNull);
        expect(config.model, 'claude-opus-5');
      });
    });

    group('setModel / model', () {
      test('stores and retrieves custom model', () {
        config.setModel('claude-opus-5');
        expect(config.model, 'claude-opus-5');
      });

      test('persists across ConfigManager instances', () {
        config.setModel('claude-opus-5');

        final config2 = ConfigManager(configDir: tempDir.path);
        expect(config2.model, 'claude-opus-5');
      });
    });

    group('read / persistence', () {
      test('persists multiple values', () {
        config
          ..setApiKey('sk-key')
          ..setModel('claude-haiku-4-5-20251001');

        final result = config.read();
        expect((result['api_keys'] as Map)['anthropic'], 'sk-key');
        expect(result['model'], 'claude-haiku-4-5-20251001');
        expect(config.apiKey, 'sk-key');
      });

      test('handles corrupt YAML gracefully', () {
        File(config.configPath)
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('key: [unclosed');

        expect(config.read(), isEmpty);
      });

      test('handles empty config file', () {
        File(config.configPath)
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('');

        expect(config.read(), isEmpty);
      });
    });

    group('YAML escaping', () {
      test('escapes values containing colons', () {
        config.setApiKey('key:with:colons');
        expect(config.apiKey, 'key:with:colons');
      });

      test('escapes values containing special characters', () {
        config.setApiKey("key'with'quotes");
        expect(config.apiKey, "key'with'quotes");
      });
    });

    group('providers', () {
      test('defaults to anthropic', () {
        expect(config.provider, LlmProvider.anthropic);
      });

      test('round-trips the active provider', () {
        config.setProvider(LlmProvider.gemini);
        expect(config.provider, LlmProvider.gemini);
      });

      test('per-provider defaults name real, documented model IDs', () {
        // Pinned deliberately: these are the exact IDs each vendor's
        // API accepts, not descriptive names. Changing one means
        // re-checking the provider's model list first.
        expect(
          ConfigManager.defaultModelFor(LlmProvider.anthropic),
          'claude-sonnet-5',
        );
        expect(
          ConfigManager.defaultModelFor(LlmProvider.openai),
          'gpt-5.6-sol',
        );
        expect(
          ConfigManager.defaultModelFor(LlmProvider.gemini),
          'gemini-3.8-flash',
        );
      });

      test('model default follows the active provider', () {
        expect(config.model, 'claude-sonnet-5');
        config.setProvider(LlmProvider.gemini);
        expect(config.model, ConfigManager.defaultModelFor(LlmProvider.gemini));
      });

      test('keys are stored per provider and do not collide', () {
        config
          ..setApiKey('sk-ant-key', target: LlmProvider.anthropic)
          ..setApiKey('sk-openai-key', target: LlmProvider.openai);

        expect(config.apiKeyFor(LlmProvider.anthropic), 'sk-ant-key');
        expect(config.apiKeyFor(LlmProvider.openai), 'sk-openai-key');
        expect(config.apiKeyFor(LlmProvider.gemini), isNull);
      });

      test('setApiKey targets the active provider by default', () {
        config
          ..setProvider(LlmProvider.openai)
          ..setApiKey('sk-openai-key');

        expect(config.apiKey, 'sk-openai-key');
        expect(config.apiKeyFor(LlmProvider.anthropic), isNull);
      });

      test('removeApiKey only clears the active provider', () {
        config
          ..setApiKey('sk-ant-key', target: LlmProvider.anthropic)
          ..setApiKey('sk-openai-key', target: LlmProvider.openai)
          ..setProvider(LlmProvider.openai)
          ..removeApiKey();

        expect(config.apiKeyFor(LlmProvider.openai), isNull);
        expect(config.apiKeyFor(LlmProvider.anthropic), 'sk-ant-key');
      });

      test('legacy flat api_key still answers for the active provider', () {
        File(config.configPath)
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('api_key: sk-legacy\nprovider: openai\n');

        expect(config.apiKey, 'sk-legacy');
      });

      test('per-provider key wins over the legacy flat key', () {
        File(config.configPath)
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(
            'api_key: sk-legacy\n'
            'api_keys:\n'
            '  anthropic: sk-scoped\n',
          );

        expect(config.apiKey, 'sk-scoped');
      });

      test("reads the provider's own env var", () {
        final withEnv = ConfigManager(
          configDir: tempDir.path,
          environment: const {'OPENAI_API_KEY': 'sk-from-env'},
        )..setProvider(LlmProvider.openai);

        expect(withEnv.apiKey, 'sk-from-env');
      });

      test('FLUTTER_SKILL_API_KEY outranks the provider env var', () {
        final withEnv = ConfigManager(
          configDir: tempDir.path,
          environment: const {
            'FLUTTER_SKILL_API_KEY': 'sk-generic',
            'OPENAI_API_KEY': 'sk-from-env',
          },
        )..setProvider(LlmProvider.openai);

        expect(withEnv.apiKey, 'sk-generic');
      });

      test('model aliases only apply to anthropic', () {
        expect(
          ConfigManager.resolveModel('opus', provider: LlmProvider.anthropic),
          'claude-opus-5',
        );
        expect(
          ConfigManager.resolveModel('opus', provider: LlmProvider.openai),
          'opus',
        );
      });

      test('round-trips a base URL', () {
        expect(config.baseUrl, isNull);
        config.setBaseUrl('https://api.deepseek.com/v1');
        expect(config.baseUrl, 'https://api.deepseek.com/v1');
      });
    });
  });
}
