// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evidence_bundle.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EvidenceBundle _$EvidenceBundleFromJson(Map<String, dynamic> json) =>
    EvidenceBundle(
      projectName: json['project_name'] as String,
      features:
          (json['features'] as List<dynamic>?)
              ?.map((e) => FeatureEvidence.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      di: DiEvidence.fromJson(json['di'] as Map<String, dynamic>),
      globalWidgetUsage:
          (json['global_widget_usage'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const {},
      knownFilePatterns:
          (json['known_file_patterns'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      fileManifest: FileManifest.fromJson(
        json['file_manifest'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$EvidenceBundleToJson(EvidenceBundle instance) =>
    <String, dynamic>{
      'project_name': instance.projectName,
      'features': instance.features.map((e) => e.toJson()).toList(),
      'di': instance.di.toJson(),
      'global_widget_usage': instance.globalWidgetUsage,
      'known_file_patterns': instance.knownFilePatterns,
      'file_manifest': instance.fileManifest.toJson(),
    };

FeatureEvidence _$FeatureEvidenceFromJson(Map<String, dynamic> json) =>
    FeatureEvidence(
      name: json['name'] as String,
      path: json['path'] as String,
      layersPresent:
          (json['layers_present'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      layersAbsent:
          (json['layers_absent'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      fileCount: (json['file_count'] as num?)?.toInt() ?? 0,
      stateClasses:
          (json['state_classes'] as List<dynamic>?)
              ?.map((e) => ClassReference.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      entityClasses:
          (json['entity_classes'] as List<dynamic>?)
              ?.map((e) => ClassReference.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      widgetUsage:
          (json['widget_usage'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const {},
      wrapperClasses:
          (json['wrapper_classes'] as List<dynamic>?)
              ?.map((e) => ClassReference.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      diFiles:
          (json['di_files'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$FeatureEvidenceToJson(
  FeatureEvidence instance,
) => <String, dynamic>{
  'name': instance.name,
  'path': instance.path,
  'layers_present': instance.layersPresent,
  'layers_absent': instance.layersAbsent,
  'file_count': instance.fileCount,
  'state_classes': instance.stateClasses.map((e) => e.toJson()).toList(),
  'entity_classes': instance.entityClasses.map((e) => e.toJson()).toList(),
  'widget_usage': instance.widgetUsage,
  'wrapper_classes': instance.wrapperClasses.map((e) => e.toJson()).toList(),
  'di_files': instance.diFiles,
};

DiEvidence _$DiEvidenceFromJson(Map<String, dynamic> json) => DiEvidence(
  style: json['style'] as String?,
  registrationFiles:
      (json['registration_files'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  perFeature: json['per_feature'] as bool? ?? false,
);

Map<String, dynamic> _$DiEvidenceToJson(DiEvidence instance) =>
    <String, dynamic>{
      'style': instance.style,
      'registration_files': instance.registrationFiles,
      'per_feature': instance.perFeature,
    };

ClassReference _$ClassReferenceFromJson(Map<String, dynamic> json) =>
    ClassReference(name: json['name'] as String, file: json['file'] as String);

Map<String, dynamic> _$ClassReferenceToJson(ClassReference instance) =>
    <String, dynamic>{'name': instance.name, 'file': instance.file};

FileManifest _$FileManifestFromJson(Map<String, dynamic> json) => FileManifest(
  allFilePaths:
      (json['all_file_paths'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  allClassNames:
      (json['all_class_names'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$FileManifestToJson(FileManifest instance) =>
    <String, dynamic>{
      'all_file_paths': instance.allFilePaths,
      'all_class_names': instance.allClassNames,
    };
