import 'package:json_annotation/json_annotation.dart';

part 'structure_info.g.dart';

/// Folder structure and organization information.
@JsonSerializable(explicitToJson: true)
class StructureInfo {
  /// Creates a [StructureInfo] instance.
  const StructureInfo({
    required this.organization,
    this.topLevelDirs = const [],
    this.featureDirs = const [],
    this.hasSeparatePackages = false,
    this.layerPattern,
    this.monorepoTool,
    this.siblingPackages = const [],
  });

  /// Creates a [StructureInfo] from JSON.
  factory StructureInfo.fromJson(Map<String, dynamic> json) =>
      _$StructureInfoFromJson(json);

  /// Organization pattern: "feature-first", "layer-first", or "hybrid".
  final String organization;

  /// Top-level directories under lib/.
  @JsonKey(name: 'top_level_dirs')
  final List<String> topLevelDirs;

  /// Feature directories detected (e.g. auth, home, cart).
  @JsonKey(name: 'feature_dirs')
  final List<String> featureDirs;

  /// Whether the project uses separate Dart/Flutter packages.
  @JsonKey(name: 'has_separate_packages')
  final bool hasSeparatePackages;

  /// Detected layer pattern details, if any.
  @JsonKey(name: 'layer_pattern')
  final LayerPattern? layerPattern;

  /// Monorepo tool detected (e.g. "melos"), or `null`.
  @JsonKey(name: 'monorepo_tool')
  final String? monorepoTool;

  /// Names of sibling packages in a monorepo.
  @JsonKey(name: 'sibling_packages')
  final List<String> siblingPackages;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$StructureInfoToJson(this);
}

/// Describes the architectural layer pattern detected in the project.
@JsonSerializable()
class LayerPattern {
  /// Creates a [LayerPattern] instance.
  const LayerPattern({
    required this.detected,
    this.layers = const [],
    this.perFeature = false,
  });

  /// Creates a [LayerPattern] from JSON.
  factory LayerPattern.fromJson(Map<String, dynamic> json) =>
      _$LayerPatternFromJson(json);

  /// The detected layer architecture name
  /// (e.g. "clean_architecture", "mvvm").
  final String detected;

  /// The layers found (e.g. ["data", "domain", "presentation"]).
  final List<String> layers;

  /// Whether each feature has its own set of layers.
  @JsonKey(name: 'per_feature')
  final bool perFeature;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$LayerPatternToJson(this);
}
