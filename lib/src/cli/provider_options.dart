import 'package:args/args.dart';

import '../ai/llm_client.dart';
import '../config/config_manager.dart';

/// The provider, model, key, and endpoint a command should generate
/// with, after CLI flags and stored config have been reconciled.
class ResolvedProvider {
  /// Creates a [ResolvedProvider].
  const ResolvedProvider({
    required this.provider,
    required this.model,
    required this.apiKey,
    required this.baseUrl,
  });

  /// Provider to call.
  final LlmProvider provider;

  /// Model ID to request.
  final String model;

  /// API key for [provider], or `null` when none is configured.
  final String? apiKey;

  /// Base URL override, or `null` for the provider's own default.
  final String? baseUrl;
}

/// Thrown when a `--provider` flag does not name a known provider.
class UnknownProviderException implements Exception {
  /// Creates an [UnknownProviderException] for [input].
  const UnknownProviderException(this.input);

  /// The unrecognised `--provider` value.
  final String input;

  @override
  String toString() =>
      'Unknown provider: $input. '
      'Options: ${LlmProvider.all.join(', ')}';
}

/// Adds the `--provider` and `--base-url` options shared by every
/// generating command.
void addProviderOptions(ArgParser parser) {
  parser
    ..addOption(
      'provider',
      help:
          'LLM provider for AI generation. '
          'Options: ${LlmProvider.all.join(', ')}. '
          'Use "openai" for any OpenAI-compatible endpoint '
          '(DeepSeek, Groq, Together, OpenRouter, Ollama, ...) '
          'together with --base-url.',
    )
    ..addOption(
      'base-url',
      help:
          'API base URL override, for OpenAI-compatible providers '
          'and Gemini. Ignored for anthropic.',
    );
}

/// Reconciles `--provider`, `--model`, and `--base-url` against the
/// stored config.
///
/// When `--provider` is passed without `--model`, the provider's own
/// default model is used rather than the stored one, which will
/// usually belong to a different vendor.
///
/// Throws [UnknownProviderException] if `--provider` is not a known
/// provider.
ResolvedProvider resolveProvider(ArgResults results, ConfigManager config) {
  final providerFlag = results.option('provider');
  final LlmProvider provider;
  if (providerFlag == null) {
    provider = config.provider;
  } else {
    final parsed = LlmProvider.tryParse(providerFlag);
    if (parsed == null) throw UnknownProviderException(providerFlag);
    provider = parsed;
  }

  final modelFlag = results.option('model');
  final String model;
  if (modelFlag != null) {
    model = ConfigManager.resolveModel(modelFlag, provider: provider);
  } else if (providerFlag != null && provider != config.provider) {
    model = ConfigManager.defaultModelFor(provider);
  } else {
    model = config.model;
  }

  return ResolvedProvider(
    provider: provider,
    model: model,
    apiKey: config.apiKeyFor(provider),
    baseUrl: results.option('base-url') ?? config.baseUrl,
  );
}
