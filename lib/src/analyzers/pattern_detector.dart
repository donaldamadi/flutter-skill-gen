import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/dependency_info.dart';
import '../models/pattern_info.dart';
import '../models/structure_info.dart';
import '../utils/file_utils.dart';

/// Detects architectural and tooling patterns by combining dependency
/// signals with folder/file naming heuristics.
class PatternDetector {
  /// Creates a [PatternDetector] with the pre-analyzed
  /// [dependencies] and [structure].
  const PatternDetector({
    required this.dependencies,
    required this.structure,
    required this.projectPath,
  });

  /// Categorized dependency information.
  final DependencyInfo dependencies;

  /// Folder structure information.
  final StructureInfo structure;

  /// Root path of the Flutter project.
  final String projectPath;

  /// Runs all pattern detections and returns a [PatternInfo].
  PatternInfo detect() {
    return PatternInfo(
      architecture: _detectArchitecture(),
      stateManagement: _detectStateManagement(),
      routing: _detectRouting(),
      di: _detectDi(),
      apiClient: _detectApiClient(),
      errorHandling: _detectErrorHandling(),
      modelApproach: _detectModelApproach(),
      i18n: _detectI18n(),
    );
  }

  // ---------------------------------------------------------------------------
  // Architecture detection
  // ---------------------------------------------------------------------------

  String? _detectArchitecture() {
    // Prefer structure-based detection since it reflects actual code layout.
    if (structure.layerPattern != null) {
      return structure.layerPattern!.detected;
    }

    // Fall back to dependency heuristics.
    final deps = _allDeps;

    if (deps.contains('stacked')) return 'mvvm_stacked';

    // If BLoC + clean arch layers in folder names, probably clean arch.
    final topDirs = structure.topLevelDirs.toSet();
    if (topDirs.containsAll(['data', 'domain', 'presentation'])) {
      return 'clean_architecture';
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // State management detection
  // ---------------------------------------------------------------------------

  String? _detectStateManagement() {
    final sm = dependencies.stateManagement;
    if (sm.isEmpty) return null;

    if (sm.contains('flutter_bloc') || sm.contains('bloc')) return 'bloc';
    if (sm.contains('flutter_riverpod') ||
        sm.contains('riverpod') ||
        sm.contains('hooks_riverpod')) {
      return 'riverpod';
    }
    if (sm.contains('provider')) return 'provider';
    if (sm.contains('get') || sm.contains('getx')) return 'getx';
    if (sm.contains('flutter_redux') || sm.contains('redux')) return 'redux';
    if (sm.contains('flutter_mobx') || sm.contains('mobx')) return 'mobx';
    if (sm.contains('signals') || sm.contains('flutter_signals')) {
      return 'signals';
    }
    if (sm.contains('stacked')) return 'stacked';

    return sm.first;
  }

  // ---------------------------------------------------------------------------
  // Routing detection
  // ---------------------------------------------------------------------------

  String? _detectRouting() {
    final r = dependencies.routing;
    if (r.isEmpty) return null;

    if (r.contains('go_router')) return 'go_router';
    if (r.contains('auto_route') || r.contains('auto_route_generator')) {
      return 'auto_route';
    }
    if (r.contains('beamer')) return 'beamer';
    if (r.contains('routemaster')) return 'routemaster';

    return r.first;
  }

  // ---------------------------------------------------------------------------
  // Dependency injection detection
  // ---------------------------------------------------------------------------

  String? _detectDi() {
    final di = dependencies.di;
    final sm = dependencies.stateManagement;

    final hasGetIt = di.contains('get_it');
    final hasInjectable =
        di.contains('injectable') || _allDeps.contains('injectable_generator');
    final hasRiverpod =
        sm.contains('riverpod') ||
        sm.contains('flutter_riverpod') ||
        sm.contains('hooks_riverpod');

    if (hasGetIt && hasInjectable) return 'get_it_injectable';
    if (hasGetIt) return 'get_it';
    if (hasRiverpod) return 'riverpod';

    return di.isNotEmpty ? di.first : null;
  }

  // ---------------------------------------------------------------------------
  // API client detection
  // ---------------------------------------------------------------------------

  String? _detectApiClient() {
    final n = dependencies.networking;
    if (n.isEmpty) return null;

    final hasDio = n.contains('dio');
    final hasRetrofit =
        n.contains('retrofit') || _allDeps.contains('retrofit_generator');
    final hasChopper =
        n.contains('chopper') || _allDeps.contains('chopper_generator');

    if (hasDio && hasRetrofit) return 'dio_retrofit';
    if (hasDio) return 'dio';
    if (hasChopper) return 'chopper';
    if (n.contains('http')) return 'http';
    if (n.contains('graphql') || n.contains('graphql_flutter')) {
      return 'graphql';
    }

    return n.first;
  }

  // ---------------------------------------------------------------------------
  // Error handling detection
  // ---------------------------------------------------------------------------

  String? _detectErrorHandling() {
    final all = _allDeps;

    if (all.contains('dartz')) return 'either_dartz';
    if (all.contains('fpdart')) return 'either_fpdart';
    if (all.contains('multiple_result')) return 'multiple_result';
    if (all.contains('result_type')) return 'result_type';

    // No functional error-handling library detected — scan source
    // for try-catch patterns to report "try_catch" rather than null.
    final libDir = Directory(p.join(projectPath, 'lib'));
    if (!libDir.existsSync()) return null;

    final files = FileUtils.collectDartFiles(libDir);
    var tryCatchCount = 0;
    for (final file in files.take(80)) {
      final content = _readFileSafe(file);
      if (content == null) continue;
      tryCatchCount += 'try {'.allMatches(content).length;
      if (tryCatchCount >= 3) return 'try_catch';
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Model approach detection
  // ---------------------------------------------------------------------------

  String? _detectModelApproach() {
    final cg = dependencies.codeGeneration;
    final all = _allDeps;

    final hasFreezed =
        cg.contains('freezed') || all.contains('freezed_annotation');
    final hasJsonSerializable =
        cg.contains('json_serializable') || all.contains('json_annotation');

    if (hasFreezed) return 'freezed';
    if (hasJsonSerializable) return 'json_serializable';

    // No code-gen library — scan source for manual patterns.
    final libDir = Directory(p.join(projectPath, 'lib'));
    if (!libDir.existsSync()) return null;

    final files = FileUtils.collectDartFiles(libDir);
    var copyWithCount = 0;
    var fromJsonCount = 0;
    for (final file in files.take(80)) {
      final content = _readFileSafe(file);
      if (content == null) continue;
      if (content.contains('copyWith(')) copyWithCount++;
      if (content.contains('fromJson(') || content.contains('toJson(')) {
        fromJsonCount++;
      }
      if (copyWithCount >= 2 || fromJsonCount >= 2) {
        return 'manual';
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Internationalization detection
  // ---------------------------------------------------------------------------

  String? _detectI18n() {
    final all = _allDeps;

    // Check for easy_localization package.
    if (all.contains('easy_localization')) return 'easy_localization';

    // Check for flutter_intl config in pubspec.yaml.
    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
    if (pubspecFile.existsSync()) {
      try {
        final content = pubspecFile.readAsStringSync();
        if (content.contains('flutter_intl:')) return 'flutter_intl';
      } on FileSystemException {
        // ignore
      }
    }

    // Check for gen_l10n (l10n.yaml file or flutter > generate: true).
    final l10nYaml = File(p.join(projectPath, 'l10n.yaml'));
    if (l10nYaml.existsSync()) return 'gen_l10n';

    if (pubspecFile.existsSync()) {
      try {
        final content = pubspecFile.readAsStringSync();
        if (RegExp(r'flutter:\s*\n\s+generate:\s*true').hasMatch(content)) {
          return 'gen_l10n';
        }
      } on FileSystemException {
        // ignore
      }
    }

    // Check for .arb files as a general signal.
    final l10nDir = Directory(p.join(projectPath, 'lib', 'l10n'));
    if (l10nDir.existsSync()) {
      try {
        final hasArb = l10nDir.listSync().any(
          (e) => e is File && e.path.endsWith('.arb'),
        );
        if (hasArb) return 'arb_based';
      } on FileSystemException {
        // ignore
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<String> get _allDeps => [
    ...dependencies.stateManagement,
    ...dependencies.routing,
    ...dependencies.di,
    ...dependencies.networking,
    ...dependencies.localStorage,
    ...dependencies.codeGeneration,
    ...dependencies.testing,
    ...dependencies.other,
  ];

  String? _readFileSafe(File file) {
    try {
      return file.readAsStringSync();
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }
}
