import 'package:json_annotation/json_annotation.dart';

part 'evidence_bundle.g.dart';

/// A verified, grounded bundle of facts about a Flutter project, used
/// as the sole evidence source for AI-powered SKILL.md generation.
///
/// Every field here is derived from direct inspection of the codebase
/// (filesystem scans, AST-like regex extraction, import counting) so
/// that downstream consumers — specifically the AI prompt builder and
/// the draft verifier — can refuse to emit any claim that is not
/// supported by this bundle.
@JsonSerializable(explicitToJson: true)
class EvidenceBundle {
  /// Creates an [EvidenceBundle] instance.
  const EvidenceBundle({
    required this.projectName,
    this.features = const [],
    required this.di,
    this.globalWidgetUsage = const {},
    this.knownFilePatterns = const [],
    required this.fileManifest,
  });

  /// Creates an [EvidenceBundle] from JSON.
  factory EvidenceBundle.fromJson(Map<String, dynamic> json) =>
      _$EvidenceBundleFromJson(json);

  /// The package name from pubspec.yaml.
  @JsonKey(name: 'project_name')
  final String projectName;

  /// Per-feature breakdown of verified facts.
  final List<FeatureEvidence> features;

  /// Project-wide dependency injection evidence.
  final DiEvidence di;

  /// Aggregated widget usage counts across all features
  /// (e.g. `{BlocBuilder: 24, BlocListener: 37}`).
  @JsonKey(name: 'global_widget_usage')
  final Map<String, int> globalWidgetUsage;

  /// File-name glob patterns that actually match at least one file
  /// in the project (e.g. `*_bloc.dart`, `*_state.dart`).
  @JsonKey(name: 'known_file_patterns')
  final List<String> knownFilePatterns;

  /// Flat manifest of file paths and class names for verifier lookups.
  @JsonKey(name: 'file_manifest')
  final FileManifest fileManifest;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$EvidenceBundleToJson(this);
}

/// Per-feature evidence, produced for every detected feature directory.
@JsonSerializable(explicitToJson: true)
class FeatureEvidence {
  /// Creates a [FeatureEvidence] instance.
  const FeatureEvidence({
    required this.name,
    required this.path,
    this.layersPresent = const [],
    this.layersAbsent = const [],
    this.fileCount = 0,
    this.stateClasses = const [],
    this.entityClasses = const [],
    this.widgetUsage = const {},
    this.wrapperClasses = const [],
    this.diFiles = const [],
  });

  /// Creates a [FeatureEvidence] from JSON.
  factory FeatureEvidence.fromJson(Map<String, dynamic> json) =>
      _$FeatureEvidenceFromJson(json);

  /// Feature name (e.g. `auth`, `home`).
  final String name;

  /// Relative path to the feature directory (e.g. `lib/features/auth`).
  final String path;

  /// Clean-Architecture-ish layers actually present as subdirectories
  /// (subset of `{"data", "domain", "presentation"}`).
  @JsonKey(name: 'layers_present')
  final List<String> layersPresent;

  /// Layers from the canonical set that are NOT present.
  @JsonKey(name: 'layers_absent')
  final List<String> layersAbsent;

  /// Number of Dart files inside this feature.
  @JsonKey(name: 'file_count')
  final int fileCount;

  /// BLoC/Cubit/Notifier classes found inside this feature, with file
  /// paths.
  @JsonKey(name: 'state_classes')
  final List<ClassReference> stateClasses;

  /// Entity/model classes found inside this feature, with file paths.
  @JsonKey(name: 'entity_classes')
  final List<ClassReference> entityClasses;

  /// Widget usage counts within this feature
  /// (e.g. `{BlocBuilder: 0, BlocListener: 12}`).
  @JsonKey(name: 'widget_usage')
  final Map<String, int> widgetUsage;

  /// Classes ending in `Wrapper`, `View`, or similar indirection
  /// patterns, with file paths.
  @JsonKey(name: 'wrapper_classes')
  final List<ClassReference> wrapperClasses;

  /// Files inside this feature that perform DI registration.
  /// Empty list means DI is NOT done per-feature here.
  @JsonKey(name: 'di_files')
  final List<String> diFiles;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$FeatureEvidenceToJson(this);
}

/// Project-wide dependency injection evidence.
@JsonSerializable()
class DiEvidence {
  /// Creates a [DiEvidence] instance.
  const DiEvidence({
    this.style,
    this.registrationFiles = const [],
    this.perFeature = false,
  });

  /// Creates a [DiEvidence] from JSON.
  factory DiEvidence.fromJson(Map<String, dynamic> json) =>
      _$DiEvidenceFromJson(json);

  /// The DI style (e.g. `get_it_injectable`, `riverpod`).
  final String? style;

  /// Concrete file paths where DI registration occurs
  /// (e.g. `["lib/core/injection_container.dart"]`).
  @JsonKey(name: 'registration_files')
  final List<String> registrationFiles;

  /// `true` iff every detected feature has at least one local DI file.
  /// `false` means DI is centralized somewhere outside feature dirs.
  @JsonKey(name: 'per_feature')
  final bool perFeature;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$DiEvidenceToJson(this);
}

/// A `(className, filePath)` pair used throughout the evidence bundle
/// to anchor class-name claims to concrete files.
@JsonSerializable()
class ClassReference {
  /// Creates a [ClassReference] instance.
  const ClassReference({required this.name, required this.file});

  /// Creates a [ClassReference] from JSON.
  factory ClassReference.fromJson(Map<String, dynamic> json) =>
      _$ClassReferenceFromJson(json);

  /// Class name as declared in the source (e.g. `AuthBloc`).
  final String name;

  /// Relative path of the file declaring the class.
  final String file;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$ClassReferenceToJson(this);
}

/// Flat lookup tables used by the draft verifier to resolve file and
/// class references from generated text.
@JsonSerializable()
class FileManifest {
  /// Creates a [FileManifest] instance.
  const FileManifest({
    this.allFilePaths = const [],
    this.allClassNames = const [],
  });

  /// Creates a [FileManifest] from JSON.
  factory FileManifest.fromJson(Map<String, dynamic> json) =>
      _$FileManifestFromJson(json);

  /// Every Dart file under `lib/`, relative to project root.
  @JsonKey(name: 'all_file_paths')
  final List<String> allFilePaths;

  /// Every top-level class name declared under `lib/`.
  @JsonKey(name: 'all_class_names')
  final List<String> allClassNames;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$FileManifestToJson(this);
}
