import 'package:json_annotation/json_annotation.dart';

part 'pattern_info.g.dart';

/// Detected architectural and tooling patterns.
@JsonSerializable()
class PatternInfo {
  /// Creates a [PatternInfo] instance.
  const PatternInfo({
    this.architecture,
    this.stateManagement,
    this.routing,
    this.di,
    this.apiClient,
    this.errorHandling,
    this.modelApproach,
    this.i18n,
  });

  /// Creates a [PatternInfo] from JSON.
  factory PatternInfo.fromJson(Map<String, dynamic> json) =>
      _$PatternInfoFromJson(json);

  /// Detected architecture pattern
  /// (e.g. "clean_architecture", "mvvm", "mvc").
  final String? architecture;

  /// Detected state management approach
  /// (e.g. "bloc", "riverpod", "provider", "getx").
  @JsonKey(name: 'state_management')
  final String? stateManagement;

  /// Detected routing solution
  /// (e.g. "go_router", "auto_route", "navigator_2").
  final String? routing;

  /// Detected dependency injection approach
  /// (e.g. "get_it_injectable", "riverpod", "manual").
  final String? di;

  /// Detected API client approach
  /// (e.g. "dio", "dio_retrofit", "http", "chopper").
  @JsonKey(name: 'api_client')
  final String? apiClient;

  /// Detected error handling pattern
  /// (e.g. "either_dartz", "either_fpdart", "exceptions").
  @JsonKey(name: 'error_handling')
  final String? errorHandling;

  /// Detected model generation approach
  /// (e.g. "freezed", "json_serializable", "manual").
  @JsonKey(name: 'model_approach')
  final String? modelApproach;

  /// Detected internationalization approach
  /// (e.g. "flutter_intl", "gen_l10n", "easy_localization").
  final String? i18n;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$PatternInfoToJson(this);
}
