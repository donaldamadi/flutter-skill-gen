// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dependency_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DependencyInfo _$DependencyInfoFromJson(
  Map<String, dynamic> json,
) => DependencyInfo(
  stateManagement:
      (json['state_management'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  routing:
      (json['routing'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  di:
      (json['di'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  networking:
      (json['networking'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  localStorage:
      (json['local_storage'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  codeGeneration:
      (json['code_generation'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  testing:
      (json['testing'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  other:
      (json['other'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$DependencyInfoToJson(DependencyInfo instance) =>
    <String, dynamic>{
      'state_management': instance.stateManagement,
      'routing': instance.routing,
      'di': instance.di,
      'networking': instance.networking,
      'local_storage': instance.localStorage,
      'code_generation': instance.codeGeneration,
      'testing': instance.testing,
      'other': instance.other,
    };
