import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../models/dependency_info.dart';
import '../utils/yaml_utils.dart';

/// Analyzes a Flutter project's pubspec.yaml to extract package metadata
/// and categorize dependencies by their role in the project.
class PubspecAnalyzer {
  /// Creates a [PubspecAnalyzer] for the project at [projectPath].
  PubspecAnalyzer(this.projectPath);

  /// Root path of the Flutter project to analyze.
  final String projectPath;

  /// Cached parsed pubspec data.
  YamlMap? _pubspec;

  // ---------------------------------------------------------------------------
  // Dependency classification maps
  // ---------------------------------------------------------------------------

  static const _stateManagementPackages = {
    'flutter_bloc',
    'bloc',
    'flutter_riverpod',
    'riverpod',
    'hooks_riverpod',
    'riverpod_annotation',
    'provider',
    'get',
    'getx',
    'flutter_redux',
    'redux',
    'mobx',
    'flutter_mobx',
    'signals',
    'flutter_signals',
    'stacked',
    'cubit',
    'rxdart',
    'hooked_bloc',
    'flutter_hooks',
  };

  static const _routingPackages = {
    'go_router',
    'auto_route',
    'auto_route_generator',
    'beamer',
    'routemaster',
    'fluro',
    'qlevar_router',
  };

  static const _diPackages = {
    'get_it',
    'injectable',
    'injectable_generator',
    'kiwi',
    'riverpod',
    'flutter_riverpod',
    'hooks_riverpod',
  };

  static const _networkingPackages = {
    'dio',
    'http',
    'retrofit',
    'retrofit_generator',
    'chopper',
    'chopper_generator',
    'graphql',
    'graphql_flutter',
    'ferry',
  };

  static const _localStoragePackages = {
    'hive',
    'hive_flutter',
    'hive_generator',
    'shared_preferences',
    'drift',
    'floor',
    'floor_generator',
    'isar',
    'isar_flutter_libs',
    'sqflite',
    'objectbox',
    'objectbox_flutter_libs',
    'realm',
    'sembast',
    'flutter_secure_storage',
  };

  static const _codeGenerationPackages = {
    'build_runner',
    'freezed',
    'freezed_annotation',
    'json_serializable',
    'json_annotation',
    'riverpod_generator',
    'injectable_generator',
    'auto_route_generator',
    'retrofit_generator',
    'hive_generator',
    'floor_generator',
    'chopper_generator',
    'envied_generator',
    'pigeon',
  };

  static const _testingPackages = {
    'bloc_test',
    'mocktail',
    'mockito',
    'flutter_test',
    'integration_test',
    'patrol',
    'golden_toolkit',
    'alchemist',
    'fake_async',
  };

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Loads and parses the pubspec.yaml file.
  ///
  /// Returns `true` if the file was loaded successfully.
  bool load() {
    _pubspec = YamlUtils.loadYamlFile(p.join(projectPath, 'pubspec.yaml'));
    return _pubspec != null;
  }

  /// Returns the package name, or "unknown" if not found.
  String get projectName => YamlUtils.getString(_pubspec!, 'name') ?? 'unknown';

  /// Returns the package description, if present.
  String? get projectDescription =>
      YamlUtils.getString(_pubspec!, 'description');

  /// Returns the Dart SDK constraint string, if present.
  String? get dartSdk {
    final env = YamlUtils.getMap(_pubspec!, 'environment');
    if (env == null) return null;
    return YamlUtils.getString(env, 'sdk');
  }

  /// Returns the Flutter SDK constraint string, if present.
  String? get flutterSdk {
    final env = YamlUtils.getMap(_pubspec!, 'environment');
    if (env == null) return null;
    return YamlUtils.getString(env, 'flutter');
  }

  /// Returns all dependency names (both dependencies and dev_dependencies).
  List<String> get allDependencyNames {
    final deps = YamlUtils.getKeys(_pubspec!, 'dependencies');
    final devDeps = YamlUtils.getKeys(_pubspec!, 'dev_dependencies');
    return [...deps, ...devDeps];
  }

  /// Returns only runtime dependency names (from `dependencies`).
  List<String> get runtimeDependencyNames =>
      YamlUtils.getKeys(_pubspec!, 'dependencies');

  /// Returns only dev dependency names (from `dev_dependencies`).
  List<String> get devDependencyNames =>
      YamlUtils.getKeys(_pubspec!, 'dev_dependencies');

  /// Categorizes all dependencies into a [DependencyInfo].
  ///
  /// Runtime dependencies are classified into their respective
  /// categories. Dev dependencies are only placed into
  /// code_generation or testing buckets — never into "other".
  DependencyInfo analyzeDependencies() {
    final runtimeDeps = runtimeDependencyNames;
    final devDeps = devDependencyNames.toSet();

    final stateManagement = <String>[];
    final routing = <String>[];
    final di = <String>[];
    final networking = <String>[];
    final localStorage = <String>[];
    final codeGeneration = <String>[];
    final testing = <String>[];
    final other = <String>[];

    void classify(String dep) {
      // Skip Flutter SDK itself and core meta-packages.
      if (dep == 'flutter' || dep == 'flutter_localizations') return;

      var categorized = false;

      if (_stateManagementPackages.contains(dep)) {
        stateManagement.add(dep);
        categorized = true;
      }
      if (_routingPackages.contains(dep)) {
        routing.add(dep);
        categorized = true;
      }
      if (_diPackages.contains(dep) && !stateManagement.contains(dep)) {
        di.add(dep);
        categorized = true;
      }
      if (_networkingPackages.contains(dep)) {
        networking.add(dep);
        categorized = true;
      }
      if (_localStoragePackages.contains(dep)) {
        localStorage.add(dep);
        categorized = true;
      }
      if (_codeGenerationPackages.contains(dep)) {
        codeGeneration.add(dep);
        categorized = true;
      }
      if (_testingPackages.contains(dep)) {
        testing.add(dep);
        categorized = true;
      }

      if (!categorized) {
        other.add(dep);
      }
    }

    // Classify runtime deps — uncategorized go to "other".
    for (final dep in runtimeDeps) {
      classify(dep);
    }

    // Classify dev deps — route generator/testing helpers into their
    // dedicated buckets, and mirror everything (minus `flutter` itself)
    // into `devDependencies` so dev-only packages like `flutter_lints`
    // survive into the generated skill.
    final devDependencies = <String>[];
    for (final dep in devDeps) {
      if (dep == 'flutter' || dep == 'flutter_localizations') {
        continue;
      }
      if (_codeGenerationPackages.contains(dep)) {
        if (!codeGeneration.contains(dep)) codeGeneration.add(dep);
      } else if (_testingPackages.contains(dep)) {
        if (!testing.contains(dep)) testing.add(dep);
      }
      if (!devDependencies.contains(dep)) devDependencies.add(dep);
    }

    return DependencyInfo(
      stateManagement: stateManagement,
      routing: routing,
      di: di,
      networking: networking,
      localStorage: localStorage,
      codeGeneration: codeGeneration,
      testing: testing,
      other: other,
      devDependencies: devDependencies,
    );
  }
}
