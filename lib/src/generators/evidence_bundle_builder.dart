import 'package:path/path.dart' as p;

import '../analyzers/structure_analyzer.dart';
import '../models/domain_facts.dart';
import '../models/evidence_bundle.dart';

/// Builds an [EvidenceBundle] from already-collected scan artifacts.
///
/// This builder is pure: it performs no filesystem I/O. All inputs
/// (file lists, class names, per-feature facts) are collected by
/// `ProjectScanner` and handed in, so the builder is trivially
/// testable with synthetic fixtures.
class EvidenceBundleBuilder {
  /// Creates an [EvidenceBundleBuilder].
  const EvidenceBundleBuilder();

  /// Canonical Clean-Architecture layer names. The `build` method
  /// reports `layersAbsent` against this set.
  static const canonicalLayers = ['data', 'domain', 'presentation'];

  /// Known central DI filenames searched when aggregating
  /// `registration_files`.
  static const _centralDiFilenames = {
    'injection.dart',
    'injection_container.dart',
    'di.dart',
    'service_locator.dart',
    'locator.dart',
    'dependencies.dart',
  };

  /// File-suffix patterns we check for in the manifest. A pattern is
  /// emitted in `known_file_patterns` only when at least one file in
  /// the project's `lib/` manifest matches it.
  static const _candidateFileSuffixes = [
    'bloc',
    'cubit',
    'state',
    'event',
    'notifier',
    'provider',
    'controller',
    'repository',
    'repository_impl',
    'usecase',
    'use_case',
    'page',
    'screen',
    'view',
    'widget',
    'model',
    'entity',
    'dto',
    'service',
    'client',
    'datasource',
    'data_source',
    'injection',
    'module',
  ];

  /// Builds an [EvidenceBundle].
  ///
  /// [allFilePaths] must be the full manifest of `.dart` files under
  /// `lib/`, relative to project root. [allClassNames] must be the
  /// union of top-level class declarations across those files.
  EvidenceBundle build({
    required String projectName,
    required List<DomainFacts> domainFacts,
    required Map<String, FeatureLayerInfo> featureBreakdown,
    required List<String> allFilePaths,
    required List<String> allClassNames,
    String? diStyle,
  }) {
    final features = _buildFeatures(domainFacts, featureBreakdown);
    final di = _buildDiEvidence(features, allFilePaths, diStyle: diStyle);
    final globalUsage = _aggregateWidgetUsage(features);
    final patterns = _detectFilePatterns(allFilePaths);

    return EvidenceBundle(
      projectName: projectName,
      features: features,
      di: di,
      globalWidgetUsage: globalUsage,
      knownFilePatterns: patterns,
      fileManifest: FileManifest(
        allFilePaths: List.unmodifiable(allFilePaths),
        allClassNames: List.unmodifiable(allClassNames),
      ),
    );
  }

  List<FeatureEvidence> _buildFeatures(
    List<DomainFacts> domainFacts,
    Map<String, FeatureLayerInfo> breakdown,
  ) {
    final features = <FeatureEvidence>[];
    for (final facts in domainFacts) {
      final layerInfo = breakdown[facts.domainName];
      final layersPresent = layerInfo?.layersPresent ?? facts.layers;
      final layersAbsent = canonicalLayers
          .where((l) => !layersPresent.contains(l))
          .toList();

      features.add(
        FeatureEvidence(
          name: facts.domainName,
          path:
              facts.featurePath ??
              layerInfo?.relativePath ??
              p.join('lib', facts.domainName),
          layersPresent: layersPresent,
          layersAbsent: layersAbsent,
          fileCount: facts.files.length,
          stateClasses: _pairClassesWithFiles(facts.stateClasses, facts.files),
          entityClasses: _pairClassesWithFiles(facts.entities, facts.files),
          widgetUsage: Map<String, int>.unmodifiable(facts.widgetUsageCounts),
          wrapperClasses: _pairClassesWithFiles(
            facts.wrapperClasses,
            facts.files,
          ),
          diFiles: List.unmodifiable(facts.diFiles),
        ),
      );
    }
    return features;
  }

  DiEvidence _buildDiEvidence(
    List<FeatureEvidence> features,
    List<String> allFilePaths, {
    String? diStyle,
  }) {
    final perFeatureDiFiles = <String>{for (final f in features) ...f.diFiles};

    final centralDiFiles = allFilePaths.where(_looksLikeCentralDi).toSet();

    final registrationFiles = {...perFeatureDiFiles, ...centralDiFiles}.toList()
      ..sort();

    // "per_feature" is true iff every feature owns at least one DI
    // file. Having zero features means we can't make the claim.
    final perFeature =
        features.isNotEmpty && features.every((f) => f.diFiles.isNotEmpty);

    return DiEvidence(
      style: diStyle,
      registrationFiles: registrationFiles,
      perFeature: perFeature,
    );
  }

  Map<String, int> _aggregateWidgetUsage(List<FeatureEvidence> features) {
    final agg = <String, int>{};
    for (final f in features) {
      f.widgetUsage.forEach((name, count) {
        agg[name] = (agg[name] ?? 0) + count;
      });
    }
    return agg;
  }

  List<String> _detectFilePatterns(List<String> allFilePaths) {
    final hits = <String>[];
    for (final suffix in _candidateFileSuffixes) {
      final pattern = RegExp('(?:^|/)[A-Za-z0-9]+_$suffix\\.dart\$');
      if (allFilePaths.any(pattern.hasMatch)) {
        hits.add('*_$suffix.dart');
      }
    }
    return hits;
  }

  /// Pairs each class name with the file most likely to declare it,
  /// using the standard `CamelCase` -> `snake_case` filename
  /// convention. Classes with no matching file get an empty `file`
  /// field — the verifier can still confirm the name against
  /// [FileManifest.allClassNames].
  List<ClassReference> _pairClassesWithFiles(
    List<String> classNames,
    List<String> featureFiles,
  ) {
    final out = <ClassReference>[];
    for (final name in classNames) {
      final snake = _toSnakeCase(name);
      final match = featureFiles.firstWhere(
        (f) =>
            p.basenameWithoutExtension(f) == snake ||
            p.basename(f) == '$snake.dart',
        orElse: () => '',
      );
      out.add(ClassReference(name: name, file: match));
    }
    return out;
  }

  bool _looksLikeCentralDi(String relativePath) {
    final basename = p.basename(relativePath).toLowerCase();
    if (_centralDiFilenames.contains(basename)) return true;
    if (basename.endsWith('_injection.dart')) return true;
    if (basename.endsWith('_di.dart')) return true;
    if (basename.endsWith('_module.dart')) return true;
    return false;
  }

  String _toSnakeCase(String name) {
    final buf = StringBuffer();
    for (var i = 0; i < name.length; i++) {
      final c = name[i];
      final upper = c == c.toUpperCase() && c != c.toLowerCase();
      if (upper && i > 0) buf.write('_');
      buf.write(c.toLowerCase());
    }
    return buf.toString();
  }
}
