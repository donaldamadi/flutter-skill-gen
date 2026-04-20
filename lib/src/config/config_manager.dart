import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Manages the flutter_skill_gen configuration stored at
/// `~/.flutter_skill_gen/config.yaml`.
class ConfigManager {
  /// Creates a [ConfigManager].
  ///
  /// Pass [configDir] to override the default `~/.flutter_skill_gen`
  /// location (useful for testing).
  ConfigManager({String? configDir})
    : _configDir =
          configDir ??
          p.join(Platform.environment['HOME'] ?? '.', '.flutter_skill_gen');

  final String _configDir;

  /// Path to the config file.
  String get configPath => p.join(_configDir, 'config.yaml');

  /// Reads the full config map. Returns empty map if no config exists.
  Map<String, dynamic> read() {
    final file = File(configPath);
    if (!file.existsSync()) return {};

    try {
      final content = file.readAsStringSync();
      final doc = loadYaml(content);
      if (doc is YamlMap) {
        return _yamlToMap(doc);
      }
      return {};
    } on YamlException {
      return {};
    }
  }

  /// Returns the stored Claude API key, or `null` if not configured.
  ///
  /// Checks the following sources in order:
  /// 1. `FLUTTER_SKILL_API_KEY` environment variable
  /// 2. `api_key` in `~/.flutter_skill_gen/config.yaml`
  String? get apiKey {
    final envKey = Platform.environment['FLUTTER_SKILL_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) return envKey;

    final config = read();
    return config['api_key'] as String?;
  }

  /// Returns whether an API key is configured.
  bool get hasApiKey {
    final key = apiKey;
    return key != null && key.isNotEmpty;
  }

  /// Stores the Claude API key.
  void setApiKey(String key) {
    _writeValue('api_key', key);
  }

  /// Removes the stored API key.
  void removeApiKey() {
    final config = read()..remove('api_key');
    _writeConfig(config);
  }

  /// Default Claude model ID. Matches the `sonnet` alias so `--model
  /// sonnet`, an unset config, and a missing flag all resolve to the
  /// same model.
  static const defaultModel = 'claude-sonnet-4-6';

  /// Short aliases that map to full Claude model IDs.
  static const modelAliases = <String, String>{
    'sonnet': 'claude-sonnet-4-6',
    'opus': 'claude-opus-4-7',
  };

  /// Resolves a model alias (e.g. "opus") or full ID to the
  /// canonical model ID.
  static String resolveModel(String input) {
    return modelAliases[input.toLowerCase()] ?? input;
  }

  /// Returns the configured Claude model ID, defaulting to Sonnet.
  String get model {
    final config = read();
    final raw = config['model'] as String?;
    if (raw == null) return defaultModel;
    return resolveModel(raw);
  }

  /// Sets the Claude model ID. Accepts aliases like "opus" or
  /// "sonnet", or a full model ID.
  void setModel(String model) {
    _writeValue('model', resolveModel(model));
  }

  // -----------------------------------------------------------------------
  // Internal helpers
  // -----------------------------------------------------------------------

  void _writeValue(String key, String value) {
    final config = read();
    config[key] = value;
    _writeConfig(config);
  }

  void _writeConfig(Map<String, dynamic> config) {
    final dir = Directory(_configDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final buffer = StringBuffer();
    for (final entry in config.entries) {
      buffer.writeln('${entry.key}: ${_yamlEscape(entry.value)}');
    }

    File(configPath).writeAsStringSync(buffer.toString());
  }

  String _yamlEscape(dynamic value) {
    if (value is String) {
      if (value.contains(':') ||
          value.contains('#') ||
          value.contains("'") ||
          value.contains('"') ||
          value.startsWith(' ') ||
          value.endsWith(' ')) {
        final escaped = value.replaceAll("'", "''");
        return "'$escaped'";
      }
      return value;
    }
    return value.toString();
  }

  Map<String, dynamic> _yamlToMap(YamlMap yamlMap) {
    final result = <String, dynamic>{};
    for (final entry in yamlMap.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is YamlMap) {
        result[key] = _yamlToMap(value);
      } else if (value is YamlList) {
        result[key] = value
            .map((e) => e is YamlMap ? _yamlToMap(e) : e)
            .toList();
      } else {
        result[key] = value;
      }
    }
    return result;
  }
}
