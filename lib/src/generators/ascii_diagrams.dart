import '../models/evidence_bundle.dart';
import '../models/project_facts.dart';

/// Deterministic ASCII architecture diagrams. Every diagram is built
/// from detected layers and stack choices, so nothing here touches the
/// hallucination surface — it's safe to append these sections verbatim
/// to any AI-generated draft.
class AsciiDiagrams {
  const AsciiDiagrams._();

  /// Project-wide architecture diagram. Chooses the template based on
  /// detected state management and the dominant layer pattern.
  /// Returns an empty string when the project has no detected state
  /// manager and no layers — printing a diagram in that case would
  /// invent structure the code doesn't have.
  static String forProject(ProjectFacts facts) {
    final sm = facts.patterns.stateManagement;
    final arch = facts.patterns.architecture;
    final hasCleanLayers =
        arch == 'clean_architecture' ||
        (facts.structure.layerPattern?.layers.length ?? 0) >= 3;

    if (sm == null && !hasCleanLayers) return '';

    final diagram = _diagramFor(sm, hasCleanLayers: hasCleanLayers);
    if (diagram == null) return '';

    return _wrap(
      heading: '## Data Flow',
      body: diagram,
      caption: _captionFor(sm, hasCleanLayers: hasCleanLayers),
    );
  }

  /// Per-feature data-flow diagram. Uses the feature's actual
  /// `layersPresent` to pick the right template — a
  /// presentation-only feature gets a simpler diagram than a
  /// full-stack one.
  static String forFeature(
    FeatureEvidence featureEvidence,
    ProjectFacts facts,
  ) {
    final layers = featureEvidence.layersPresent.toSet();
    final hasData = layers.contains('data');
    final hasDomain = layers.contains('domain');
    final hasPresentation = layers.contains('presentation');
    final sm = facts.patterns.stateManagement;

    if (!hasPresentation && !hasDomain && !hasData) return '';

    final diagram = _featureDiagram(
      sm: sm,
      hasData: hasData,
      hasDomain: hasDomain,
      hasPresentation: hasPresentation,
    );
    if (diagram == null) return '';

    return _wrap(
      heading: '## Data Flow',
      body: diagram,
      caption: _featureCaption(
        featureEvidence.name,
        hasData: hasData,
        hasDomain: hasDomain,
      ),
    );
  }

  // ---------------------------------------------------------------
  // Project-level templates
  // ---------------------------------------------------------------

  static String? _diagramFor(String? sm, {required bool hasCleanLayers}) {
    if (hasCleanLayers) {
      return _cleanArchDiagram(sm);
    }
    return switch (sm) {
      'bloc' => _blocDiagram,
      'riverpod' => _riverpodDiagram,
      'provider' => _providerDiagram,
      'getx' => _getxDiagram,
      _ => null,
    };
  }

  static String _cleanArchDiagram(String? sm) {
    final stateNode = switch (sm) {
      'bloc' => 'Bloc/Cubit',
      'riverpod' => 'Notifier',
      'provider' => 'ChangeNotifier',
      'getx' => 'Controller',
      _ => 'State holder',
    };
    return '''
  data/              domain/               presentation/
  ─────              ──────                ────────────
  DTOs        ──►    Entities       ──►    Widgets
    │                  ▲                     ▲
    ▼                  │                     │
  DataSources ──►    UseCases       ──►    $stateNode
    │                  ▲
    ▼                  │
  Repositories ──►   Repository  (interface)
''';
  }

  static const _blocDiagram = '''
  Widget ──►  Event  ──►  Bloc/Cubit  ──►  State  ──►  BlocBuilder rebuild
                            │
                            ▼
                         Repository  ──►  DataSource
''';

  static const _riverpodDiagram = '''
  Widget ──►  ref.read callback  ──►  Notifier  ──►  State update
     ▲                                   │
     │                                   ▼
  ref.watch  ◄────────────────────  Repository  ──►  DataSource
''';

  static const _providerDiagram = '''
  Widget ──►  context.read  ──►  ChangeNotifier  ──►  notifyListeners()
     ▲                              │
     │                              ▼
  context.watch  ◄──────────  Repository  ──►  DataSource
''';

  static const _getxDiagram = '''
  Widget ──►  controller.method()  ──►  GetxController  ──►  .value = ...
     ▲                                       │
     │                                       ▼
  Obx rebuild  ◄────────────────────    Repository  ──►  DataSource
''';

  static String _captionFor(String? sm, {required bool hasCleanLayers}) {
    if (hasCleanLayers) {
      return 'Arrows show the dependency direction. The domain layer '
          'imports nothing; data and presentation both depend on it.';
    }
    return switch (sm) {
      'bloc' =>
        'Events flow in, states flow out. Build UI off `BlocBuilder` / '
            '`BlocSelector`, never off raw instance fields.',
      'riverpod' =>
        '`ref.watch` inside `build` subscribes; `ref.read` in '
            'callbacks fires once. Don\'t cross the streams.',
      'provider' =>
        '`context.watch` subscribes; `context.read` is a one-shot '
            'lookup. Using `read` inside `build` hides bugs.',
      'getx' =>
        'State changes propagate through `Rx` values; wrap reactive '
            'widgets in `Obx`. Pull controllers via `Get.find()`.',
      _ => '',
    };
  }

  // ---------------------------------------------------------------
  // Feature-level templates
  // ---------------------------------------------------------------

  static String? _featureDiagram({
    required String? sm,
    required bool hasData,
    required bool hasDomain,
    required bool hasPresentation,
  }) {
    // Full clean-arch feature.
    if (hasData && hasDomain && hasPresentation) {
      return _cleanArchDiagram(sm);
    }
    // Presentation-only feature (very common).
    if (hasPresentation && !hasData && !hasDomain) {
      return switch (sm) {
        'bloc' => _blocDiagram,
        'riverpod' => _riverpodDiagram,
        'provider' => _providerDiagram,
        'getx' => _getxDiagram,
        _ =>
          '''
  Widget  ──►  <stateless or locally-stateful UI only>
''',
      };
    }
    // Data + presentation (no dedicated domain layer).
    if (hasData && hasPresentation && !hasDomain) {
      final stateNode = switch (sm) {
        'bloc' => 'Bloc/Cubit',
        'riverpod' => 'Notifier',
        'provider' => 'ChangeNotifier',
        'getx' => 'Controller',
        _ => 'State holder',
      };
      return '''
  data/                       presentation/
  ─────                       ────────────
  DataSources ──►  Repository ──►  $stateNode ──►  Widget
''';
    }
    // Data-only (rare): just the pipeline.
    if (hasData && !hasPresentation) {
      return '''
  DataSources  ──►  Repository
''';
    }
    return null;
  }

  static String _featureCaption(
    String name, {
    required bool hasData,
    required bool hasDomain,
  }) {
    if (hasData && hasDomain) {
      return 'Full Clean Architecture layering — keep `domain/` '
          'import-free of Flutter and `data/`.';
    }
    if (hasData && !hasDomain) {
      return 'No domain layer in `$name/` — repositories and entities '
          'live in `data/` directly. Revisit if business logic starts '
          'leaking into presentation.';
    }
    return 'Presentation-only feature. State stays local until a '
        'concrete data need appears.';
  }

  // ---------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------

  static String _wrap({
    required String heading,
    required String body,
    required String caption,
  }) {
    final buf = StringBuffer()
      ..writeln(heading)
      ..writeln()
      ..writeln('```')
      ..write(body)
      ..writeln('```')
      ..writeln();
    if (caption.isNotEmpty) {
      buf
        ..writeln(caption)
        ..writeln();
    }
    return buf.toString();
  }
}
