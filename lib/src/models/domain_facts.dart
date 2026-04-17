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
    this.files = const [],
    this.samples = const [],
    this.layers = const [],
    this.stateClasses = const [],
    this.entities = const [],
  });

  /// Creates a [DomainFacts] from JSON.
  factory DomainFacts.fromJson(Map<String, dynamic> json) =>
      _$DomainFactsFromJson(json);

  /// Name of this domain/feature (e.g. "auth", "home", "cart").
  @JsonKey(name: 'domain_name')
  final String domainName;

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

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$DomainFactsToJson(this);
}
