// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'structure_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StructureInfo _$StructureInfoFromJson(Map<String, dynamic> json) =>
    StructureInfo(
      organization: json['organization'] as String,
      topLevelDirs:
          (json['top_level_dirs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      featureDirs:
          (json['feature_dirs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      hasSeparatePackages: json['has_separate_packages'] as bool? ?? false,
      layerPattern: json['layer_pattern'] == null
          ? null
          : LayerPattern.fromJson(
              json['layer_pattern'] as Map<String, dynamic>,
            ),
      monorepoTool: json['monorepo_tool'] as String?,
      siblingPackages:
          (json['sibling_packages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$StructureInfoToJson(StructureInfo instance) =>
    <String, dynamic>{
      'organization': instance.organization,
      'top_level_dirs': instance.topLevelDirs,
      'feature_dirs': instance.featureDirs,
      'has_separate_packages': instance.hasSeparatePackages,
      'layer_pattern': instance.layerPattern?.toJson(),
      'monorepo_tool': instance.monorepoTool,
      'sibling_packages': instance.siblingPackages,
    };

LayerPattern _$LayerPatternFromJson(Map<String, dynamic> json) => LayerPattern(
  detected: json['detected'] as String,
  layers:
      (json['layers'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  perFeature: json['per_feature'] as bool? ?? false,
);

Map<String, dynamic> _$LayerPatternToJson(LayerPattern instance) =>
    <String, dynamic>{
      'detected': instance.detected,
      'layers': instance.layers,
      'per_feature': instance.perFeature,
    };
