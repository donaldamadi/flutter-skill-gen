// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'convention_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConventionInfo _$ConventionInfoFromJson(Map<String, dynamic> json) =>
    ConventionInfo(
      naming: json['naming'] == null
          ? null
          : NamingConvention.fromJson(json['naming'] as Map<String, dynamic>),
      imports: json['imports'] == null
          ? null
          : ImportConvention.fromJson(json['imports'] as Map<String, dynamic>),
      samples:
          (json['samples'] as List<dynamic>?)
              ?.map((e) => CodeSample.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ConventionInfoToJson(ConventionInfo instance) =>
    <String, dynamic>{
      'naming': instance.naming?.toJson(),
      'imports': instance.imports?.toJson(),
      'samples': instance.samples.map((e) => e.toJson()).toList(),
    };

NamingConvention _$NamingConventionFromJson(Map<String, dynamic> json) =>
    NamingConvention(
      files: json['files'] as String?,
      classes: json['classes'] as String?,
      blocEvents: json['bloc_events'] as String?,
      blocStates: json['bloc_states'] as String?,
      stateStyle: json['state_style'] as String?,
    );

Map<String, dynamic> _$NamingConventionToJson(NamingConvention instance) =>
    <String, dynamic>{
      'files': instance.files,
      'classes': instance.classes,
      'bloc_events': instance.blocEvents,
      'bloc_states': instance.blocStates,
      'state_style': instance.stateStyle,
    };

ImportConvention _$ImportConventionFromJson(Map<String, dynamic> json) =>
    ImportConvention(
      style: json['style'] as String?,
      barrelFiles: json['barrel_files'] as bool? ?? false,
    );

Map<String, dynamic> _$ImportConventionToJson(ImportConvention instance) =>
    <String, dynamic>{
      'style': instance.style,
      'barrel_files': instance.barrelFiles,
    };

CodeSample _$CodeSampleFromJson(Map<String, dynamic> json) => CodeSample(
  type: json['type'] as String,
  file: json['file'] as String,
  snippet: json['snippet'] as String,
);

Map<String, dynamic> _$CodeSampleToJson(CodeSample instance) =>
    <String, dynamic>{
      'type': instance.type,
      'file': instance.file,
      'snippet': instance.snippet,
    };
