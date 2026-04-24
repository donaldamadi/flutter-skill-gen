import 'package:json_annotation/json_annotation.dart';

part 'dependency_info.g.dart';

/// Categorized dependency information extracted from pubspec.yaml.
@JsonSerializable()
class DependencyInfo {
  /// Creates a [DependencyInfo] instance.
  const DependencyInfo({
    this.stateManagement = const [],
    this.routing = const [],
    this.di = const [],
    this.networking = const [],
    this.localStorage = const [],
    this.codeGeneration = const [],
    this.testing = const [],
    this.other = const [],
    this.devDependencies = const [],
  });

  /// Creates a [DependencyInfo] from JSON.
  factory DependencyInfo.fromJson(Map<String, dynamic> json) =>
      _$DependencyInfoFromJson(json);

  /// State management packages (e.g. flutter_bloc, riverpod, provider).
  @JsonKey(name: 'state_management')
  final List<String> stateManagement;

  /// Routing packages (e.g. go_router, auto_route).
  final List<String> routing;

  /// Dependency injection packages (e.g. get_it, injectable).
  final List<String> di;

  /// Networking packages (e.g. dio, http, retrofit).
  final List<String> networking;

  /// Local storage packages (e.g. hive, shared_preferences, drift).
  @JsonKey(name: 'local_storage')
  final List<String> localStorage;

  /// Code generation packages (e.g. freezed, json_serializable).
  @JsonKey(name: 'code_generation')
  final List<String> codeGeneration;

  /// Testing packages (e.g. bloc_test, mocktail, mockito).
  final List<String> testing;

  /// All other dependencies not fitting the above categories.
  final List<String> other;

  /// Raw list of every entry in `dev_dependencies` (minus `flutter` itself).
  /// Preserved so dev-only packages like `flutter_lints` show up in generated
  /// skill files without being forced into the runtime "other" bucket.
  @JsonKey(name: 'dev_dependencies')
  final List<String> devDependencies;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$DependencyInfoToJson(this);
}
