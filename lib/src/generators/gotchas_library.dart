import '../models/evidence_bundle.dart';
import '../models/project_facts.dart';

/// A single pre-authored gotcha — a short, high-signal rule derived
/// deterministically from the detected stack. Keyed by technology or
/// stack combo, not by project specifics, so every claim can be
/// emitted without touching the hallucination surface.
class Gotcha {
  /// Creates a [Gotcha].
  const Gotcha({required this.title, required this.body});

  /// Bold lead-in sentence, e.g. `Bloc events must be immutable`.
  final String title;

  /// One or two sentences of explanation. Rendered verbatim after the
  /// title in the output bullet.
  final String body;

  /// Renders the gotcha as a single markdown bullet: `- **<title>.** <body>`.
  String toMarkdown() => '- **$title.** $body';
}

/// Deterministic library of stack-specific gotchas. Every rule is
/// authored from public-library semantics — nothing here references
/// project-specific identifiers, so the draft verifier never has to
/// second-guess this content.
class GotchasLibrary {
  const GotchasLibrary._();

  /// Gotchas relevant to the project as a whole (state management,
  /// DI, routing, codegen, persistence).
  static List<Gotcha> forProject(ProjectFacts facts) {
    final p = facts.patterns;
    final deps = facts.dependencies;
    final result = <Gotcha>[];

    // ----- State management -----
    if (p.stateManagement == 'bloc') {
      result
        ..add(
          const Gotcha(
            title: 'Bloc events must be immutable',
            body:
                'If an event carries a mutable `List` or `Map`, wrap it '
                'in `UnmodifiableListView` or pass a copy. Mutating it '
                'inside the handler corrupts state comparisons and '
                'makes `BlocBuilder`\'s `buildWhen` misfire.',
          ),
        )
        ..add(
          const Gotcha(
            title: 'Close streams explicitly',
            body:
                'Blocs, Cubits, and any `StreamSubscription` fields '
                'must be disposed in `close()`. A leaked subscription '
                'on a logged-out user is the easiest way to crash the '
                'next session.',
          ),
        );
    }

    if (p.stateManagement == 'riverpod') {
      result
        ..add(
          const Gotcha(
            title: 'Never call `ref.read` inside `build`',
            body:
                'It won\'t rebuild on change and the resulting widget '
                'lies about its dependencies. Use `ref.watch` in '
                '`build`, `ref.read` only from callbacks.',
          ),
        )
        ..add(
          const Gotcha(
            title: 'Don\'t capture `ref` in closures that outlive the provider',
            body:
                'When scheduling work (timers, navigation, futures), '
                'read values you need up front or pass `ref` through a '
                '`Ref` parameter — a captured `ref` from a disposed '
                'notifier throws at runtime.',
          ),
        );
    }

    if (p.stateManagement == 'provider') {
      result.add(
        const Gotcha(
          title: 'Use `context.read` vs `context.watch` intentionally',
          body:
              '`watch` inside `build` subscribes and rebuilds; `read` '
              'gets a one-shot value. Using `read` where you need '
              '`watch` yields a UI that silently goes stale.',
        ),
      );
    }

    // ----- Routing -----
    if (p.routing == 'go_router') {
      result.add(
        const Gotcha(
          title: '`context.go` replaces the stack, `context.push` adds to it',
          body:
              'If you push a modal and then call `go` to leave it, you '
              'lose the `push` return value entirely. Always `pop` '
              'modals; reserve `go` for top-level route transitions.',
        ),
      );
    }
    if (p.routing == 'auto_route') {
      result.add(
        const Gotcha(
          title: 'Regenerate routes after any `@RoutePage()` change',
          body:
              '`auto_route` builds its router from generated '
              '`.gr.dart` files. Adding a page without rerunning '
              '`build_runner` leaves you with green compilation and '
              'a runtime `UnknownRouteException`.',
        ),
      );
    }

    // ----- DI -----
    if (p.di == 'get_it_injectable') {
      result.add(
        const Gotcha(
          title: 'Call `configureDependencies()` before `runApp()`',
          body:
              'Any `GetIt.I<T>()` before the container is configured '
              'throws `Object/factory of type T is not registered` at '
              'runtime. Put the call in `main()` as the first '
              'statement inside the `WidgetsFlutterBinding.ensureInitialized` '
              'scope.',
        ),
      );
    }

    // ----- Codegen -----
    final cg = deps.codeGeneration;
    if (cg.contains('freezed') || cg.contains('json_serializable')) {
      result.add(
        const Gotcha(
          title: 'Rerun build_runner after every annotated-class edit',
          body:
              'Stale `.g.dart` and `.freezed.dart` files compile green '
              'but drift from the source until serialization or '
              'equality quietly breaks. Use `dart run build_runner '
              'build --delete-conflicting-outputs` after any change '
              'to a `@freezed`, `@JsonSerializable`, or `@injectable` '
              'class.',
        ),
      );
    }

    // ----- Error handling -----
    if (p.errorHandling == 'either_dartz' ||
        p.errorHandling == 'either_fpdart') {
      result.add(
        const Gotcha(
          title: 'Never let network exceptions leak past the repository',
          body:
              'Data sources throw; repositories return `Either<Failure, '
              'T>`. Letting a `DioException` or `SocketException` bubble '
              'to the UI forces presentation code to handle '
              'framework-level errors it has no business knowing about.',
        ),
      );
    }

    // ----- Storage pair rules -----
    final storage = deps.localStorage;
    if (storage.contains('hive') && cg.contains('freezed')) {
      result.add(
        const Gotcha(
          title: 'Hive + freezed needs a hand-written adapter',
          body:
              'You cannot stack `@HiveType` and `@freezed` on the same '
              'class. Either keep the Hive model as a plain class and '
              'map to/from a freezed domain entity, or register a '
              'custom `TypeAdapter` for the freezed class.',
        ),
      );
    }

    // ----- Stack pair rule -----
    if (p.di == 'get_it_injectable' && p.stateManagement == 'riverpod') {
      result.add(
        const Gotcha(
          title: 'Don\'t mix Riverpod and GetIt for the same dependency',
          body:
              'Register each dependency once. A safe split is GetIt '
              'for infrastructure (clients, storage, configs) and '
              'Riverpod for application/presentation state — expose '
              'GetIt-registered singletons through a Riverpod '
              'provider when the UI needs them.',
        ),
      );
    }

    // ----- Structure rules -----
    final evidence = facts.evidence;
    if (evidence != null) {
      final missingDomain = evidence.features
          .where((f) => f.layersAbsent.contains('domain'))
          .map((f) => f.name)
          .toList();
      if (p.architecture == 'clean_architecture' && missingDomain.isNotEmpty) {
        final list = missingDomain.take(3).join(', ');
        final more = missingDomain.length > 3 ? ' (+ others)' : '';
        result.add(
          Gotcha(
            title: 'Some features are missing their domain layer',
            body:
                '`$list`$more has no `domain/` directory. Landing use '
                'cases directly in `data/` or `presentation/` subverts '
                'the Clean Architecture boundaries the rest of the '
                'project relies on.',
          ),
        );
      }
    }

    final topLevel = facts.structure.topLevelDirs.toSet();
    if (facts.structure.organization == 'feature-first' &&
        !topLevel.contains('core') &&
        !topLevel.contains('shared')) {
      result.add(
        const Gotcha(
          title: 'No shared layer — watch for cross-feature drift',
          body:
              'With no `lib/core/` or `lib/shared/`, cross-cutting '
              'code (theming, error types, network client) has to '
              'live somewhere. Without a shared home it usually ends '
              'up duplicated inside individual features — extract '
              'early, not during a rewrite.',
        ),
      );
    }

    return result;
  }

  /// Gotchas scoped to a single feature, derived from the feature's
  /// `layersAbsent` list and the project-wide stack. Returns an empty
  /// list when nothing feature-specific is worth flagging — generic
  /// stack gotchas live in [forProject].
  static List<Gotcha> forFeature(
    FeatureEvidence featureEvidence,
    ProjectFacts facts,
  ) {
    final result = <Gotcha>[];

    if (facts.patterns.architecture == 'clean_architecture') {
      if (featureEvidence.layersAbsent.contains('domain')) {
        result.add(
          const Gotcha(
            title: 'This feature has no domain layer',
            body:
                'Use cases and business rules currently live in `data/` '
                'or `presentation/`. New logic for this feature should '
                'land in a fresh `domain/` directory (entities, '
                'repositories as interfaces, use cases) to keep the '
                'presentation layer UI-only.',
          ),
        );
      }
      if (featureEvidence.layersAbsent.contains('data')) {
        result.add(
          const Gotcha(
            title: 'This feature has no data layer',
            body:
                'Without `data/`, there are no repository '
                'implementations or data sources — the presentation '
                'layer is reaching for something directly. Wire a real '
                'data source before adding features that need '
                'persistence or networking.',
          ),
        );
      }
    }

    return result;
  }

  /// Renders a `## Gotchas` markdown section from [gotchas]. Returns
  /// an empty string when the list is empty so callers can splice the
  /// result without an empty-heading check.
  static String renderSection(List<Gotcha> gotchas) {
    if (gotchas.isEmpty) return '';
    final buf = StringBuffer()
      ..writeln('## Gotchas')
      ..writeln();
    for (final g in gotchas) {
      buf.writeln(g.toMarkdown());
    }
    buf.writeln();
    return buf.toString();
  }
}
