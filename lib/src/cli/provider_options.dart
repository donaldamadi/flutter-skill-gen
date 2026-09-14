import 'package:args/args.dart';

import '../ai/agent_cli_client.dart';
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

  /// Returns a description of why AI generation will not run, or
  /// `null` when it is ready.
  ///
  /// Callers report this as a warning rather than an error: a missing
  /// key or a missing `claude` binary still produces a skill file via
  /// the template fallback, so it is never fatal.
  String? get unavailableReason {
    if (!provider.requiresApiKey) {
      final agent = agentCliFor(provider);
      if (agent == null) return null;
      final executable = AgentCliClient.resolveExecutable(agent);
      if (AgentCliClient.isAvailable(executable: executable)) return null;
      return 'The "$executable" CLI is not on your PATH, so generation '
          'will fall back to templates. Install it, point '
          '${agent.executableEnvVar} at it, or pick a provider with an '
          'API key.';
    }

    final key = apiKey;
    if (key == null || key.isEmpty) {
      return 'No API key configured for "${provider.id}", so '
          'generation will fall back to templates. Set one with '
          '--set-key, or run keyless with --provider claude-code, '
          'codex, or gemini-cli.';
    }

    return null;
  }
}

/// Returns the agent CLI [provider] drives, or `null` when it talks to
/// a hosted API instead.
AgentCli? agentCliFor(LlmProvider provider) => switch (provider) {
  LlmProvider.claudeCode => AgentCli.claudeCode,
  LlmProvider.codex => AgentCli.codex,
  LlmProvider.geminiCli => AgentCli.geminiCli,
  _ => null,
};

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
          'Use "claude-code", "codex", or "gemini-cli" to generate '
          'through a locally installed agent CLI with no API key. '
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
