import '../models/domain_facts.dart';
import '../models/project_facts.dart';

/// Generates a SKILL.md from [ProjectFacts] using templates.
///
/// This is the fallback generator used when no Claude API key is
/// configured. It produces a structured but less nuanced skill file
/// compared to the AI-powered generator.
class TemplateGenerator {
  const TemplateGenerator._();

  /// Generates the full SKILL.md markdown content from [facts].
  static String generate(ProjectFacts facts) {
    final buf = StringBuffer();

    _writeHeader(buf, facts);
    _writeArchitecture(buf, facts);
    _writeStateManagement(buf, facts);
    _writeRouting(buf, facts);
    _writeDi(buf, facts);
    _writeDataLayer(buf, facts);
    _writeConventions(buf, facts);
    _writeRules(buf, facts);
    _writeTesting(buf, facts);
    _writeCodeGeneration(buf, facts);

    return buf.toString();
  }

  /// Generates the **core** SKILL.md for split mode.
  ///
  /// Same structure as [generate] but excludes feature-specific code
  /// samples — those go into domain skill files.
  static String generateCore(ProjectFacts facts) {
    final buf = StringBuffer();

    _writeHeader(buf, facts);
    _writeArchitecture(buf, facts);
    _writeStateManagement(buf, facts);
    _writeRouting(buf, facts);
    _writeDi(buf, facts);
    _writeDataLayer(buf, facts);

    // Write conventions without code samples (those are per-domain).
    final naming = facts.conventions.naming;
    final imports = facts.conventions.imports;
    if (naming != null || imports != null) {
      buf
        ..writeln('## Code Conventions')
        ..writeln();
      if (naming != null) {
        if (naming.files != null) {
          buf.writeln('- File naming: **${naming.files}**');
        }
        if (naming.classes != null) {
          buf.writeln('- Class naming: **${naming.classes}**');
        }
        if (naming.stateStyle != null) {
          buf.writeln('- State style: **${naming.stateStyle}**');
        }
      }
      if (imports != null) {
        if (imports.style != null) {
          buf.writeln('- Import style: **${imports.style}**');
        }
        buf.writeln(
          '- Barrel files: '
          '**${imports.barrelFiles ? 'yes' : 'no'}**',
        );
      }
      buf.writeln();
    }

    _writeRules(buf, facts);
    _writeTesting(buf, facts);
    _writeCodeGeneration(buf, facts);

    return buf.toString();
  }

  /// Generates a **domain-specific** SKILL.md from [domainFacts].
  static String generateDomain(
    DomainFacts domainFacts,
    ProjectFacts projectFacts,
  ) {
    final buf = StringBuffer()
      ..writeln('# ${_humanize(domainFacts.domainName)} Domain')
      ..writeln()
      ..writeln('## Overview')
      ..writeln()
      ..writeln(
        'The **${domainFacts.domainName}** feature in '
        '${projectFacts.projectName}.',
      )
      ..writeln();

    if (domainFacts.layers.isNotEmpty) {
      buf
        ..writeln('Layers: `${domainFacts.layers.join('`, `')}`')
        ..writeln();
    }

    buf
      ..writeln('Files: ${domainFacts.files.length} Dart files')
      ..writeln();

    // State classes.
    if (domainFacts.stateClasses.isNotEmpty) {
      buf
        ..writeln('## State Management')
        ..writeln()
        ..writeln(
          'State classes: '
          '`${domainFacts.stateClasses.join('`, `')}`',
        )
        ..writeln();
    }

    // Entities.
    if (domainFacts.entities.isNotEmpty) {
      buf
        ..writeln('## Entities & Models')
        ..writeln()
        ..writeln('`${domainFacts.entities.join('`, `')}`')
        ..writeln();
    }

    // Code samples.
    if (domainFacts.samples.isNotEmpty) {
      buf
        ..writeln('## Code Samples')
        ..writeln();
      for (final sample in domainFacts.samples) {
        buf
          ..writeln(
            '### ${_humanize(sample.type)} '
            '(`${sample.file}`)',
          )
          ..writeln()
          ..writeln('```dart')
          ..writeln(sample.snippet)
          ..writeln('```')
          ..writeln();
      }
    }

    return buf.toString();
  }

  // ---------------------------------------------------------------
  // Section writers
  // ---------------------------------------------------------------

  static void _writeHeader(StringBuffer buf, ProjectFacts facts) {
    buf
      ..writeln('# ${facts.projectName}')
      ..writeln();

    if (facts.projectDescription != null) {
      buf
        ..writeln(facts.projectDescription)
        ..writeln();
    }

    final stack = <String>[];
    if (facts.patterns.architecture != null) {
      stack.add(_humanize(facts.patterns.architecture!));
    }
    if (facts.patterns.stateManagement != null) {
      stack.add(_humanize(facts.patterns.stateManagement!));
    }
    if (facts.patterns.routing != null) {
      stack.add(_humanize(facts.patterns.routing!));
    }
    if (stack.isNotEmpty) {
      buf
        ..writeln('**Tech stack:** ${stack.join(' · ')}')
        ..writeln();
    }

    if (facts.dartSdk != null) {
      buf.writeln('**Dart SDK:** `${facts.dartSdk}`');
    }
    if (facts.flutterSdk != null) {
      buf.writeln('**Flutter SDK:** `${facts.flutterSdk}`');
    }
    if (facts.dartSdk != null || facts.flutterSdk != null) {
      buf.writeln();
    }
  }

  static void _writeArchitecture(StringBuffer buf, ProjectFacts facts) {
    buf
      ..writeln('## Architecture')
      ..writeln();

    final arch = facts.patterns.architecture;
    final org = facts.structure.organization;

    if (arch != null) {
      buf.writeln(
        'This project uses **${_humanize(arch)}** with a '
        '**$org** folder organization.',
      );
    } else {
      buf.writeln('This project uses a **$org** folder organization.');
    }
    buf.writeln();

    if (facts.structure.topLevelDirs.isNotEmpty) {
      buf
        ..writeln(
          'Top-level directories under `lib/`: '
          '`${facts.structure.topLevelDirs.join('`, `')}`',
        )
        ..writeln();
    }

    if (facts.structure.featureDirs.isNotEmpty) {
      buf
        ..writeln(
          'Features: '
          '`${facts.structure.featureDirs.join('`, `')}`',
        )
        ..writeln();
    }

    final lp = facts.structure.layerPattern;
    if (lp != null) {
      buf
        ..writeln(
          'Each ${lp.perFeature ? 'feature' : 'top-level module'} '
          'contains these layers: '
          '`${lp.layers.join('`, `')}`',
        )
        ..writeln();
    }

    if (facts.structure.hasSeparatePackages) {
      buf
        ..writeln(
          'This is a **monorepo** with separate Dart/Flutter '
          'packages under `packages/`.',
        )
        ..writeln();
    }
  }

  static void _writeStateManagement(StringBuffer buf, ProjectFacts facts) {
    final sm = facts.patterns.stateManagement;
    if (sm == null) return;

    buf
      ..writeln('## State Management')
      ..writeln()
      ..writeln('State management: **${_humanize(sm)}**')
      ..writeln();

    final deps = facts.dependencies.stateManagement;
    if (deps.isNotEmpty) {
      buf
        ..writeln('Packages: `${deps.join('`, `')}`')
        ..writeln();
    }

    final naming = facts.conventions.naming;
    if (naming != null) {
      if (naming.blocEvents != null) {
        buf.writeln('- BLoC events: ${naming.blocEvents}');
      }
      if (naming.blocStates != null) {
        buf.writeln('- BLoC states: ${naming.blocStates}');
      }
      if (naming.blocEvents != null || naming.blocStates != null) {
        buf.writeln();
      }
    }
  }

  static void _writeRouting(StringBuffer buf, ProjectFacts facts) {
    final routing = facts.patterns.routing;
    if (routing == null) return;

    buf
      ..writeln('## Routing')
      ..writeln()
      ..writeln('Router: **${_humanize(routing)}**')
      ..writeln();

    final deps = facts.dependencies.routing;
    if (deps.isNotEmpty) {
      buf
        ..writeln('Packages: `${deps.join('`, `')}`')
        ..writeln();
    }
  }

  static void _writeDi(StringBuffer buf, ProjectFacts facts) {
    final di = facts.patterns.di;
    if (di == null) return;

    buf
      ..writeln('## Dependency Injection')
      ..writeln()
      ..writeln('DI approach: **${_humanize(di)}**')
      ..writeln();

    final deps = facts.dependencies.di;
    if (deps.isNotEmpty) {
      buf
        ..writeln('Packages: `${deps.join('`, `')}`')
        ..writeln();
    }
  }

  static void _writeDataLayer(StringBuffer buf, ProjectFacts facts) {
    final api = facts.patterns.apiClient;
    final storage = facts.dependencies.localStorage;
    final errorHandling = facts.patterns.errorHandling;
    final modelApproach = facts.patterns.modelApproach;

    if (api == null &&
        storage.isEmpty &&
        errorHandling == null &&
        modelApproach == null) {
      return;
    }

    buf
      ..writeln('## Data Layer')
      ..writeln();

    if (api != null) {
      buf.writeln('API client: **${_humanize(api)}**');
      final netDeps = facts.dependencies.networking;
      if (netDeps.isNotEmpty) {
        buf.writeln('Networking packages: `${netDeps.join('`, `')}`');
      }
      buf.writeln();
    }

    if (storage.isNotEmpty) {
      buf
        ..writeln('Local storage: `${storage.join('`, `')}`')
        ..writeln();
    }

    if (errorHandling != null) {
      buf
        ..writeln('Error handling: **${_humanize(errorHandling)}**')
        ..writeln();
    }

    if (modelApproach != null) {
      buf
        ..writeln('Model serialization: **${_humanize(modelApproach)}**')
        ..writeln();
    }
  }

  static void _writeConventions(StringBuffer buf, ProjectFacts facts) {
    final naming = facts.conventions.naming;
    final imports = facts.conventions.imports;
    final samples = facts.conventions.samples;

    if (naming == null && imports == null && samples.isEmpty) {
      return;
    }

    buf
      ..writeln('## Code Conventions')
      ..writeln();

    if (naming != null) {
      if (naming.files != null) {
        buf.writeln('- File naming: **${naming.files}**');
      }
      if (naming.classes != null) {
        buf.writeln('- Class naming: **${naming.classes}**');
      }
    }

    if (imports != null) {
      if (imports.style != null) {
        buf.writeln('- Import style: **${imports.style}**');
      }
      buf.writeln(
        '- Barrel files: '
        '**${imports.barrelFiles ? 'yes' : 'no'}**',
      );
    }
    buf.writeln();

    if (samples.isNotEmpty) {
      for (final sample in samples) {
        buf
          ..writeln(
            '### ${_humanize(sample.type)} '
            '(`${sample.file}`)',
          )
          ..writeln()
          ..writeln('```dart')
          ..writeln(sample.snippet)
          ..writeln('```')
          ..writeln();
      }
    }
  }

  static void _writeRules(StringBuffer buf, ProjectFacts facts) {
    final rules = _deriveRules(facts);
    if (rules.isEmpty) return;

    buf
      ..writeln("## Do / Don't Rules")
      ..writeln();
    for (final rule in rules) {
      buf.writeln('- $rule');
    }
    buf.writeln();
  }

  static void _writeTesting(StringBuffer buf, ProjectFacts facts) {
    final t = facts.testing;
    if (t == null) return;

    buf
      ..writeln('## Testing')
      ..writeln();

    final types = <String>[];
    if (t.hasUnitTests) types.add('unit');
    if (t.hasWidgetTests) types.add('widget');
    if (t.hasIntegrationTests) types.add('integration');

    if (types.isNotEmpty) {
      buf.writeln('Test types present: ${types.join(', ')}');
    }
    if (t.mockingLibrary != null) {
      buf.writeln('Mocking library: **${t.mockingLibrary}**');
    }
    if (t.testStructure != null) {
      buf.writeln('Test structure: **${t.testStructure}**');
    }
    buf.writeln();
  }

  static void _writeCodeGeneration(StringBuffer buf, ProjectFacts facts) {
    final cg = facts.dependencies.codeGeneration;
    if (cg.isEmpty) return;

    buf
      ..writeln('## Code Generation')
      ..writeln()
      ..writeln(
        'This project uses code generation with: '
        '`${cg.join('`, `')}`',
      )
      ..writeln()
      ..writeln('Run code generation with:')
      ..writeln()
      ..writeln('```bash')
      ..writeln('dart run build_runner build --delete-conflicting-outputs')
      ..writeln('```')
      ..writeln();

    if (cg.contains('freezed')) {
      buf
        ..writeln(
          'Regenerate after modifying any `@freezed` or '
          '`@JsonSerializable` annotated class.',
        )
        ..writeln();
    }
  }

  // ---------------------------------------------------------------
  // Rule derivation
  // ---------------------------------------------------------------

  static List<String> _deriveRules(ProjectFacts facts) {
    final rules = <String>[];
    final p = facts.patterns;

    if (p.architecture == 'clean_architecture') {
      rules.add(
        '**DO** follow Clean Architecture layer boundaries — '
        'domain must not import from data or presentation.',
      );
    }

    if (p.stateManagement == 'bloc') {
      rules
        ..add(
          '**DO** use BLoC/Cubit for all state management. '
          'Do not mix with other state solutions.',
        )
        ..add(
          '**DO** name events as `PascalCase` ending with '
          '`Event` and states ending with `State`.',
        );
    }

    if (p.stateManagement == 'riverpod') {
      rules.add(
        '**DO** use Riverpod providers for all state '
        'management and dependency injection.',
      );
    }

    if (p.modelApproach == 'freezed') {
      rules.add(
        '**DO** use `freezed` for all data classes and '
        'union types. Run `build_runner` after changes.',
      );
    } else if (p.modelApproach == 'json_serializable') {
      rules.add(
        '**DO** use `json_serializable` for all model '
        'serialization. Run `build_runner` after changes.',
      );
    }

    if (p.errorHandling == 'either_dartz' ||
        p.errorHandling == 'either_fpdart') {
      rules.add(
        '**DO** use `Either` for error handling in '
        'repositories and use cases — never throw exceptions '
        'across layer boundaries.',
      );
    }

    final imports = facts.conventions.imports;
    if (imports != null && imports.style != null) {
      if (imports.style == 'relative') {
        rules.add(
          '**DO** use relative imports for project files. '
          "**DON'T** use package imports for internal files.",
        );
      } else if (imports.style == 'package') {
        rules.add(
          '**DO** use package imports for project files. '
          "**DON'T** use relative imports.",
        );
      }
    }

    if (facts.structure.organization == 'feature-first') {
      rules.add(
        '**DO** keep all feature code inside its own '
        '`features/<name>/` directory. Shared code goes '
        'in `core/` or `shared/`.',
      );
    }

    if (p.di == 'get_it_injectable') {
      rules.add(
        '**DO** annotate injectable classes with '
        '`@injectable` / `@singleton`. Register via '
        '`build_runner`, not manually.',
      );
    }

    return rules;
  }

  // ---------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------

  /// Converts `snake_case` or `slug-case` identifiers to
  /// human-readable form: `clean_architecture` → `Clean Architecture`.
  static String _humanize(String id) {
    return id
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
