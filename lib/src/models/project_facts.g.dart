// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_facts.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProjectFacts _$ProjectFactsFromJson(Map<String, dynamic> json) => ProjectFacts(
  projectName: json['project_name'] as String,
  projectDescription: json['project_description'] as String?,
  flutterSdk: json['flutter_sdk'] as String?,
  dartSdk: json['dart_sdk'] as String?,
  dependencies: DependencyInfo.fromJson(
    json['dependencies'] as Map<String, dynamic>,
  ),
  structure: StructureInfo.fromJson(json['structure'] as Map<String, dynamic>),
  patterns: PatternInfo.fromJson(json['patterns'] as Map<String, dynamic>),
  conventions: ConventionInfo.fromJson(
    json['conventions'] as Map<String, dynamic>,
  ),
  testing: json['testing'] == null
      ? null
      : TestingInfo.fromJson(json['testing'] as Map<String, dynamic>),
  complexity: json['complexity'] == null
      ? null
      : ComplexityInfo.fromJson(json['complexity'] as Map<String, dynamic>),
  evidence: json['evidence'] == null
      ? null
      : EvidenceBundle.fromJson(json['evidence'] as Map<String, dynamic>),
  generatedAt: json['generated_at'] as String,
  toolVersion: json['tool_version'] as String,
);

Map<String, dynamic> _$ProjectFactsToJson(ProjectFacts instance) =>
    <String, dynamic>{
      'project_name': instance.projectName,
      'project_description': instance.projectDescription,
      'flutter_sdk': instance.flutterSdk,
      'dart_sdk': instance.dartSdk,
      'dependencies': instance.dependencies.toJson(),
      'structure': instance.structure.toJson(),
      'patterns': instance.patterns.toJson(),
      'conventions': instance.conventions.toJson(),
      'testing': instance.testing?.toJson(),
      'complexity': instance.complexity?.toJson(),
      'evidence': instance.evidence?.toJson(),
      'generated_at': instance.generatedAt,
      'tool_version': instance.toolVersion,
    };

TestingInfo _$TestingInfoFromJson(Map<String, dynamic> json) => TestingInfo(
  hasUnitTests: json['has_unit_tests'] as bool? ?? false,
  hasWidgetTests: json['has_widget_tests'] as bool? ?? false,
  hasIntegrationTests: json['has_integration_tests'] as bool? ?? false,
  mockingLibrary: json['mocking_library'] as String?,
  testStructure: json['test_structure'] as String?,
);

Map<String, dynamic> _$TestingInfoToJson(TestingInfo instance) =>
    <String, dynamic>{
      'has_unit_tests': instance.hasUnitTests,
      'has_widget_tests': instance.hasWidgetTests,
      'has_integration_tests': instance.hasIntegrationTests,
      'mocking_library': instance.mockingLibrary,
      'test_structure': instance.testStructure,
    };

ComplexityInfo _$ComplexityInfoFromJson(Map<String, dynamic> json) =>
    ComplexityInfo(
      totalDartFiles: (json['total_dart_files'] as num?)?.toInt() ?? 0,
      totalFeatures: (json['total_features'] as num?)?.toInt() ?? 0,
      estimatedMagnitude: json['estimated_magnitude'] as String? ?? 'small',
      recommendedSkillFiles:
          (json['recommended_skill_files'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ComplexityInfoToJson(ComplexityInfo instance) =>
    <String, dynamic>{
      'total_dart_files': instance.totalDartFiles,
      'total_features': instance.totalFeatures,
      'estimated_magnitude': instance.estimatedMagnitude,
      'recommended_skill_files': instance.recommendedSkillFiles,
    };
