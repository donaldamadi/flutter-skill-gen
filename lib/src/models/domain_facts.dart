import 'package:json_annotation/json_annotation.dart';

import 'convention_info.dart';

part 'domain_facts.g.dart';

/// Domain-scoped analysis facts for a single feature/domain within a
/// Flutter project.
///
/// Used during split-mode generation to provide focused context when
/// generating domain-specific SKILL files.
@JsonSerializable(explicitToJson: true)
class DomainFacts {
  /// Creates a [DomainFacts] instance.
  const DomainFacts({
    required this.domainName,
    this.featurePath,
    this.files = const [],
    this.samples = const [],
    this.layers = const [],
    this.stateClasses = const [],
    this.entities = const [],
    this.diFiles = const [],
    this.widgetUsageCounts = const {},
    this.wrapperClasses = const [],
  });

  /// Creates a [DomainFacts] from JSON.
  factory DomainFacts.fromJson(Map<String, dynamic> json) =>
      _$DomainFactsFromJson(json);

  /// Name of this domain/feature (e.g. "auth", "home", "cart").
  @JsonKey(name: 'domain_name')
  final String domainName;

  /// Relative path to the feature directory (e.g.
  /// `lib/features/auth`). Null for legacy-loaded facts that predate
  /// this field.
  @JsonKey(name: 'feature_path')
  final String? featurePath;

  /// Relative file paths belonging to this domain.
  final List<String> files;

  /// Representative code samples from this domain's files.
  final List<CodeSample> samples;

  /// Architectural layers found in this domain
  /// (e.g. ["data", "domain", "presentation"]).
  final List<String> layers;

  /// BLoC/Cubit/Notifier class names found in this domain.
  @JsonKey(name: 'state_classes')
  final List<String> stateClasses;

  /// Entity/model class names found in this domain.
  final List<String> entities;

  /// Files inside this feature that perform DI registration.
  /// Empty list means DI is NOT done per-feature here.
  @JsonKey(name: 'di_files')
  final List<String> diFiles;

  /// Widget usage counts within this feature (e.g.
  /// `{BlocBuilder: 0, BlocListener: 12, Consumer: 3}`).
  @JsonKey(name: 'widget_usage_counts')
  final Map<String, int> widgetUsageCounts;

  /// Class names within this feature that look like indirection
  /// wrappers (ending in `Wrapper`, `View`, etc.).
  @JsonKey(name: 'wrapper_classes')
  final List<String> wrapperClasses;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$DomainFactsToJson(this);
}
