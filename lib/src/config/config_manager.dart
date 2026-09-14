import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../ai/agent_cli_client.dart';
import '../ai/llm_client.dart';

/// Manages the flutter_skill_gen configuration stored at
/// `~/.flutter_skill_gen/config.yaml`.
class ConfigManager {
  /// Creates a [ConfigManager].
  ///
  /// Pass [configDir] to override the default `~/.flutter_skill_gen`
  /// location (useful for testing).
  ConfigManager({String? configDir, Map<String, String>? environment})
    : _configDir =
          configDir ??
          p.join(Platform.environment['HOME'] ?? '.', '.flutter_skill_gen'),
      _env = environment ?? Platform.environment;

  final String _configDir;
  final Map<String, String> _env;

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

  /// Config key holding the per-provider API key map.
  static const apiKeysKey = 'api_keys';

  /// Config key holding the pre-multi-provider single API key.
  ///
  /// Still read as a last-resort fallback so configs written before
  /// provider support keep working.
  static const legacyApiKeyKey = 'api_key';

  /// Environment variable that overrides every stored key, whatever
  /// the active provider.
  static const apiKeyEnvVar = 'FLUTTER_SKILL_API_KEY';

  /// The provider's own conventional environment variable.
  ///
  /// Empty for providers that carry their own credentials and so read
  /// no key from the environment.
  static String envVarFor(LlmProvider provider) => switch (provider) {
    LlmProvider.anthropic => 'ANTHROPIC_API_KEY',
    LlmProvider.openai => 'OPENAI_API_KEY',
    LlmProvider.gemini => 'GEMINI_API_KEY',
    LlmProvider.claudeCode => '',
    LlmProvider.codex => '',
    LlmProvider.geminiCli => '',
  };

  /// Returns the API key for the active provider, or `null` if none
  /// is configured.
  ///
  /// Checks the following sources in order:
  /// 1. `FLUTTER_SKILL_API_KEY` environment variable
  /// 2. the active provider's own env var (`OPENAI_API_KEY`, ...)
  /// 3. `api_keys.<provider>` in `~/.flutter_skill_gen/config.yaml`
  /// 4. the legacy flat `api_key` in the same file
  String? get apiKey => apiKeyFor(provider);

  /// Returns the stored API key for [target], independent of which
  /// provider is currently active.
  ///
  /// Always `null` for providers that carry their own credentials —
  /// handing `claude-code` a stray `ANTHROPIC_API_KEY` would only
  /// mislead `config --show`.
  String? apiKeyFor(LlmProvider target) {
    if (!target.requiresApiKey) return null;

    final envKey = _env[apiKeyEnvVar];
    if (envKey != null && envKey.isNotEmpty) return envKey;

    final providerEnvKey = _env[envVarFor(target)];
    if (providerEnvKey != null && providerEnvKey.isNotEmpty) {
      return providerEnvKey;
    }

    final config = read();
    final keys = config[apiKeysKey];
    if (keys is Map) {
      final stored = keys[target.id];
      if (stored is String && stored.isNotEmpty) return stored;
    }

    return config[legacyApiKeyKey] as String?;
  }

  /// Returns whether an API key is configured for the active
  /// provider.
  bool get hasApiKey {
    final key = apiKey;
    return key != null && key.isNotEmpty;
  }

  /// Stores [key] for the active provider, or for [target] when
  /// given.
  void setApiKey(String key, {LlmProvider? target}) {
    final slot = target ?? provider;
    final config = read();
    final existing = config[apiKeysKey];
    final keys = <String, dynamic>{
      if (existing is Map)
        for (final entry in existing.entries) entry.key.toString(): entry.value,
      slot.id: key,
    };
    config[apiKeysKey] = keys;
    _writeConfig(config);
  }

  /// Removes the stored key for the active provider, or for [target]
  /// when given.
  ///
  /// Also drops the legacy flat `api_key`, which would otherwise
  /// keep answering for every provider.
  void removeApiKey({LlmProvider? target}) {
    final slot = target ?? provider;
    final config = read()..remove(legacyApiKeyKey);
    final existing = config[apiKeysKey];
    if (existing is Map) {
      final keys = <String, dynamic>{
        for (final entry in existing.entries) entry.key.toString(): entry.value,
      }..remove(slot.id);
      if (keys.isEmpty) {
        config.remove(apiKeysKey);
      } else {
        config[apiKeysKey] = keys;
      }
    }
    _writeConfig(config);
  }

  // -----------------------------------------------------------------------
  // Provider
  // -----------------------------------------------------------------------

  /// Provider used when none is configured.
  static const defaultProvider = LlmProvider.anthropic;

  /// Returns the configured provider, defaulting to Anthropic.
  LlmProvider get provider {
    final raw = read()['provider'] as String?;
    if (raw == null) return defaultProvider;
    return LlmProvider.tryParse(raw) ?? defaultProvider;
  }

  /// Sets the active provider.
  void setProvider(LlmProvider provider) {
    _writeValue('provider', provider.id);
  }

  /// Returns the configured API base URL override, or `null` to use
  /// the provider's own default.
  ///
  /// Only meaningful for OpenAI-compatible providers and Gemini; the
  /// Anthropic client's endpoint is fixed.
  String? get baseUrl {
    final raw = read()['base_url'] as String?;
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  /// Sets the API base URL used for OpenAI-compatible providers.
  void setBaseUrl(String url) {
    _writeValue('base_url', url);
  }

  /// Default Anthropic model ID. Matches the `sonnet` alias so
  /// `--model sonnet`, an unset config, and a missing flag all
  /// resolve to the same model.
  static const defaultModel = 'claude-sonnet-5';

  /// Model used for a provider when the config names none.
  ///
  /// The OpenAI and Gemini entries are starting points only — both
  /// vendors retire and rename model IDs frequently, so set `model`
  /// explicitly rather than relying on these.
  static String defaultModelFor(LlmProvider provider) => switch (provider) {
    LlmProvider.anthropic => defaultModel,
    LlmProvider.openai => 'gpt-5.6-sol',
    LlmProvider.gemini => 'gemini-3.8-flash',
    LlmProvider.claudeCode => AgentCli.claudeCode.defaultModel,
    LlmProvider.codex => AgentCli.codex.defaultModel,
    LlmProvider.geminiCli => AgentCli.geminiCli.defaultModel,
  };

  /// Short aliases that map to full Claude model IDs.
  static const modelAliases = <String, String>{
    'sonnet': 'claude-sonnet-5',
    'opus': 'claude-opus-5',
  };

  /// Resolves a model alias (e.g. "opus") or full ID to the
  /// canonical model ID.
  ///
  /// Aliases name Claude models, so they only apply when Anthropic is
  /// the active provider — otherwise the input passes through and the
  /// provider decides whether it knows the model.
  static String resolveModel(
    String input, {
    LlmProvider provider = defaultProvider,
  }) {
    if (provider != LlmProvider.anthropic) return input;
    return modelAliases[input.toLowerCase()] ?? input;
  }

  /// Returns the configured model ID, defaulting to the active
  /// provider's default.
  String get model {
    final config = read();
    final raw = config['model'] as String?;
    final active = provider;
    if (raw == null) return defaultModelFor(active);
    return resolveModel(raw, provider: active);
  }

  /// Sets the Claude model ID. Accepts aliases like "opus" or
  /// "sonnet", or a full model ID.
  void setModel(String model) {
    _writeValue('model', resolveModel(model, provider: provider));
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
      final value = entry.value;
      if (value is Map) {
        buffer.writeln('${entry.key}:');
        for (final nested in value.entries) {
          buffer.writeln('  ${nested.key}: ${_yamlEscape(nested.value)}');
        }
      } else {
        buffer.writeln('${entry.key}: ${_yamlEscape(value)}');
      }
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
