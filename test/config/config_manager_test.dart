import 'dart:io';

import 'package:flutter_skill_gen/src/config/config_manager.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late ConfigManager config;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'flutter_skill_gen_config_test_',
    );
    config = ConfigManager(configDir: tempDir.path);
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
      expect(config.model, 'claude-sonnet-4-6');
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
          ..setModel('claude-opus-4-7')
          ..removeApiKey();
        expect(config.apiKey, isNull);
        expect(config.model, 'claude-opus-4-7');
      });
    });

    group('setModel / model', () {
      test('stores and retrieves custom model', () {
        config.setModel('claude-opus-4-7');
        expect(config.model, 'claude-opus-4-7');
      });

      test('persists across ConfigManager instances', () {
        config.setModel('claude-opus-4-7');

        final config2 = ConfigManager(configDir: tempDir.path);
        expect(config2.model, 'claude-opus-4-7');
      });
    });

    group('read / persistence', () {
      test('persists multiple values', () {
        config
          ..setApiKey('sk-key')
          ..setModel('claude-haiku-4-5-20251001');

        final result = config.read();
        expect(result['api_key'], 'sk-key');
        expect(result['model'], 'claude-haiku-4-5-20251001');
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
  });
}
