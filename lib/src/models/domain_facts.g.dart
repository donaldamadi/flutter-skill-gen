// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'domain_facts.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DomainFacts _$DomainFactsFromJson(Map<String, dynamic> json) => DomainFacts(
  domainName: json['domain_name'] as String,
  featurePath: json['feature_path'] as String?,
  files:
      (json['files'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  samples:
      (json['samples'] as List<dynamic>?)
          ?.map((e) => CodeSample.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  layers:
      (json['layers'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  stateClasses:
      (json['state_classes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  entities:
      (json['entities'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  diFiles:
      (json['di_files'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  widgetUsageCounts:
      (json['widget_usage_counts'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const {},
  wrapperClasses:
      (json['wrapper_classes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$DomainFactsToJson(DomainFacts instance) =>
    <String, dynamic>{
      'domain_name': instance.domainName,
      'feature_path': instance.featurePath,
      'files': instance.files,
      'samples': instance.samples.map((e) => e.toJson()).toList(),
      'layers': instance.layers,
      'state_classes': instance.stateClasses,
      'entities': instance.entities,
      'di_files': instance.diFiles,
      'widget_usage_counts': instance.widgetUsageCounts,
      'wrapper_classes': instance.wrapperClasses,
    };
