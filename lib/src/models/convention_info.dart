import 'package:json_annotation/json_annotation.dart';

part 'convention_info.g.dart';

/// Code convention information extracted from the project.
@JsonSerializable(explicitToJson: true)
class ConventionInfo {
  /// Creates a [ConventionInfo] instance.
  const ConventionInfo({this.naming, this.imports, this.samples = const []});

  /// Creates a [ConventionInfo] from JSON.
  factory ConventionInfo.fromJson(Map<String, dynamic> json) =>
      _$ConventionInfoFromJson(json);

  /// Naming conventions detected.
  final NamingConvention? naming;

  /// Import style conventions detected.
  final ImportConvention? imports;

  /// Representative code samples showing conventions in use.
  final List<CodeSample> samples;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$ConventionInfoToJson(this);
}

/// Naming conventions detected in the project.
@JsonSerializable()
class NamingConvention {
  /// Creates a [NamingConvention] instance.
  const NamingConvention({
    this.files,
    this.classes,
    this.blocEvents,
    this.blocStates,
    this.stateStyle,
  });

  /// Creates a [NamingConvention] from JSON.
  factory NamingConvention.fromJson(Map<String, dynamic> json) =>
      _$NamingConventionFromJson(json);

  /// File naming convention (e.g. "snake_case").
  final String? files;

  /// Class naming convention (e.g. "PascalCase").
  final String? classes;

  /// BLoC event naming convention, if applicable.
  @JsonKey(name: 'bloc_events')
  final String? blocEvents;

  /// BLoC state naming convention, if applicable.
  @JsonKey(name: 'bloc_states')
  final String? blocStates;

  /// Whether the project uses "bloc" (with events), "cubit_only",
  /// or "mixed". Null if neither is detected.
  @JsonKey(name: 'state_style')
  final String? stateStyle;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$NamingConventionToJson(this);
}

/// Import style conventions detected in the project.
@JsonSerializable()
class ImportConvention {
  /// Creates an [ImportConvention] instance.
  const ImportConvention({this.style, this.barrelFiles = false});

  /// Creates an [ImportConvention] from JSON.
  factory ImportConvention.fromJson(Map<String, dynamic> json) =>
      _$ImportConventionFromJson(json);

  /// Import style (e.g. "relative", "package", "mixed").
  final String? style;

  /// Whether barrel files (index exports) are used.
  @JsonKey(name: 'barrel_files')
  final bool barrelFiles;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$ImportConventionToJson(this);
}

/// A representative code sample from the project.
@JsonSerializable()
class CodeSample {
  /// Creates a [CodeSample] instance.
  const CodeSample({
    required this.type,
    required this.file,
    required this.snippet,
  });

  /// Creates a [CodeSample] from JSON.
  factory CodeSample.fromJson(Map<String, dynamic> json) =>
      _$CodeSampleFromJson(json);

  /// The kind of sample (e.g. "bloc_example", "repository_example").
  final String type;

  /// The relative file path the sample was extracted from.
  final String file;

  /// The actual code snippet.
  final String snippet;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$CodeSampleToJson(this);
}
