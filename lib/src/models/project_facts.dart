import 'package:json_annotation/json_annotation.dart';

import 'convention_info.dart';
import 'dependency_info.dart';
import 'evidence_bundle.dart';
import 'pattern_info.dart';
import 'structure_info.dart';

part 'project_facts.g.dart';

/// The complete set of facts extracted from a Flutter project.
///
/// This is the intermediate data model that gets serialized to
/// `.skill_facts.json` and serves as the contract between the
/// static scanner (Phase 1) and the AI synthesis engine (Phase 2).
@JsonSerializable(explicitToJson: true)
class ProjectFacts {
  /// Creates a [ProjectFacts] instance.
  const ProjectFacts({
    required this.projectName,
    this.projectDescription,
    this.flutterSdk,
    this.dartSdk,
    required this.dependencies,
    required this.structure,
    required this.patterns,
    required this.conventions,
    this.testing,
    this.complexity,
    this.evidence,
    required this.generatedAt,
    required this.toolVersion,
  });

  /// Creates a [ProjectFacts] from JSON.
  factory ProjectFacts.fromJson(Map<String, dynamic> json) =>
      _$ProjectFactsFromJson(json);

  /// The package name from pubspec.yaml.
  @JsonKey(name: 'project_name')
  final String projectName;

  /// The package description from pubspec.yaml.
  @JsonKey(name: 'project_description')
  final String? projectDescription;

  /// Flutter SDK constraint, if present.
  @JsonKey(name: 'flutter_sdk')
  final String? flutterSdk;

  /// Dart SDK constraint.
  @JsonKey(name: 'dart_sdk')
  final String? dartSdk;

  /// Categorized dependency information.
  final DependencyInfo dependencies;

  /// Folder structure and organization information.
  final StructureInfo structure;

  /// Detected architectural and tooling patterns.
  final PatternInfo patterns;

  /// Code convention information.
  final ConventionInfo conventions;

  /// Testing information, if tests were found.
  final TestingInfo? testing;

  /// Project complexity metrics.
  final ComplexityInfo? complexity;

  /// Verified evidence bundle used to ground AI-generated skill files.
  /// Null for facts loaded from pre-0.2.0 JSON.
  final EvidenceBundle? evidence;

  /// ISO 8601 timestamp when the facts were generated.
  @JsonKey(name: 'generated_at')
  final String generatedAt;

  /// The version of flutter_skill_gen that generated these facts.
  @JsonKey(name: 'tool_version')
  final String toolVersion;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$ProjectFactsToJson(this);
}

/// Testing infrastructure information.
@JsonSerializable()
class TestingInfo {
  /// Creates a [TestingInfo] instance.
  const TestingInfo({
    this.hasUnitTests = false,
    this.hasWidgetTests = false,
    this.hasIntegrationTests = false,
    this.mockingLibrary,
    this.testStructure,
  });

  /// Creates a [TestingInfo] from JSON.
  factory TestingInfo.fromJson(Map<String, dynamic> json) =>
      _$TestingInfoFromJson(json);

  /// Whether unit tests exist.
  @JsonKey(name: 'has_unit_tests')
  final bool hasUnitTests;

  /// Whether widget tests exist.
  @JsonKey(name: 'has_widget_tests')
  final bool hasWidgetTests;

  /// Whether integration tests exist.
  @JsonKey(name: 'has_integration_tests')
  final bool hasIntegrationTests;

  /// Detected mocking library (e.g. "mocktail", "mockito").
  @JsonKey(name: 'mocking_library')
  final String? mockingLibrary;

  /// How tests are organized (e.g. "mirrors_lib", "flat").
  @JsonKey(name: 'test_structure')
  final String? testStructure;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$TestingInfoToJson(this);
}

/// Project complexity and magnitude metrics.
@JsonSerializable()
class ComplexityInfo {
  /// Creates a [ComplexityInfo] instance.
  const ComplexityInfo({
    this.totalDartFiles = 0,
    this.totalFeatures = 0,
    this.estimatedMagnitude = 'small',
    this.recommendedSkillFiles = const [],
  });

  /// Creates a [ComplexityInfo] from JSON.
  factory ComplexityInfo.fromJson(Map<String, dynamic> json) =>
      _$ComplexityInfoFromJson(json);

  /// Total number of .dart files in the project.
  @JsonKey(name: 'total_dart_files')
  final int totalDartFiles;

  /// Total number of detected features/modules.
  @JsonKey(name: 'total_features')
  final int totalFeatures;

  /// Estimated project magnitude: "small", "medium", or "large".
  @JsonKey(name: 'estimated_magnitude')
  final String estimatedMagnitude;

  /// Recommended skill file scopes based on complexity analysis.
  @JsonKey(name: 'recommended_skill_files')
  final List<String> recommendedSkillFiles;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$ComplexityInfoToJson(this);
}
