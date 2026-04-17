import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/structure_info.dart';
import '../utils/file_utils.dart';

/// Analyzes a Flutter project's folder structure to determine organization
/// patterns, feature modules, and layer boundaries.
class StructureAnalyzer {
  /// Creates a [StructureAnalyzer] for the project at [projectPath].
  StructureAnalyzer(this.projectPath);

  /// Root path of the Flutter project to analyze.
  final String projectPath;

  /// Well-known layer directory names used in Clean Architecture / MVVM / MVC.
  static const _layerNames = {
    'data',
    'domain',
    'presentation',
    'infrastructure',
    'application',
    'view',
    'viewmodel',
    'view_model',
    'controller',
    'model',
    'ui',
    'bloc',
    'state',
    'cubit',
    'repository',
    'repositories',
    'datasource',
    'datasources',
    'data_source',
    'data_sources',
    'service',
    'services',
    'usecase',
    'usecases',
    'use_case',
    'use_cases',
    'entity',
    'entities',
  };

  /// Names commonly used for shared/core modules rather than features.
  static const _nonFeatureNames = {
    'core',
    'common',
    'shared',
    'utils',
    'util',
    'utilities',
    'helpers',
    'helper',
    'theme',
    'themes',
    'config',
    'configuration',
    'constants',
    'const',
    'di',
    'injection',
    'l10n',
    'localization',
    'gen',
    'generated',
    'widgets',
    'components',
    'extensions',
    'mixins',
    'routing',
    'routes',
    'navigation',
    'app',
    ..._layerNames,
  };

  /// Analyzes the project structure and returns a [StructureInfo].
  StructureInfo analyze() {
    final libDir = Directory(p.join(projectPath, 'lib'));
    if (!libDir.existsSync()) {
      return const StructureInfo(organization: 'unknown');
    }

    final topLevelDirs = FileUtils.listSubdirectories(libDir);
    final featureDirs = _detectFeatures(libDir, topLevelDirs);
    final hasSeparatePackages = _detectSeparatePackages();
    final organization = _detectOrganization(topLevelDirs, featureDirs);
    final layerPattern = _detectLayerPattern(libDir, topLevelDirs, featureDirs);
    final monorepo = _detectMonorepo();

    return StructureInfo(
      organization: organization,
      topLevelDirs: topLevelDirs,
      featureDirs: featureDirs,
      hasSeparatePackages: hasSeparatePackages || monorepo.packages.isNotEmpty,
      layerPattern: layerPattern,
      monorepoTool: monorepo.tool,
      siblingPackages: monorepo.packages,
    );
  }

  /// Detects feature directories by excluding known non-feature names.
  ///
  /// Checks multiple locations in priority order:
  /// 1. Explicit `features/`, `modules/`, `feature/`, `pages/` container
  /// 2. Nested features inside `presentation/pages/` or
  ///    `presentation/features/` (layer-first projects)
  /// 3. Fallback: top-level dirs that aren't well-known non-feature names
  List<String> _detectFeatures(Directory libDir, List<String> topLevelDirs) {
    // 1. Check for an explicit top-level feature container.
    const featureContainerNames = ['features', 'modules', 'feature', 'pages'];
    for (final containerName in featureContainerNames) {
      final containerDir = Directory(p.join(libDir.path, containerName));
      if (containerDir.existsSync()) {
        return FileUtils.listSubdirectories(containerDir);
      }
    }

    // 2. For layer-first projects, look for features nested inside
    //    presentation layer (e.g. presentation/pages/*, presentation/features/*).
    const presentationSubContainers = [
      'presentation/pages',
      'presentation/features',
      'presentation/screens',
      'ui/pages',
      'ui/features',
      'ui/screens',
    ];
    for (final sub in presentationSubContainers) {
      final containerDir = Directory(p.join(libDir.path, sub));
      if (containerDir.existsSync()) {
        final subdirs = FileUtils.listSubdirectories(containerDir);
        if (subdirs.length >= 2) return subdirs;
      }
    }

    // 3. Fallback: top-level dirs that aren't well-known non-feature names.
    return topLevelDirs
        .where((dir) => !_nonFeatureNames.contains(dir))
        .toList();
  }

  /// Detects whether the project uses separate Dart/Flutter packages
  /// (monorepo-style).
  ///
  /// Checks for a `packages/` directory both within the project root
  /// and in the parent directory (common in monorepos where the app
  /// is a sibling of `packages/`).
  bool _detectSeparatePackages() {
    final candidates = [
      Directory(p.join(projectPath, 'packages')),
      Directory(p.join(projectPath, '..', 'packages')),
    ];

    for (final packagesDir in candidates) {
      if (packagesDir.existsSync()) {
        final hasSubPackage = packagesDir.listSync().whereType<Directory>().any(
          (d) => File(p.join(d.path, 'pubspec.yaml')).existsSync(),
        );
        if (hasSubPackage) return true;
      }
    }
    return false;
  }

  /// Detects monorepo tooling and sibling package names.
  _MonorepoInfo _detectMonorepo() {
    // Walk up to find the monorepo root (up to 3 levels).
    for (var i = 0; i <= 2; i++) {
      final ancestor = p.normalize(
        p.join(projectPath, List.filled(i, '..').join('/')),
      );

      // Check for Melos.
      final melosFile = File(p.join(ancestor, 'melos.yaml'));
      if (melosFile.existsSync()) {
        return _MonorepoInfo(
          tool: 'melos',
          packages: _collectSiblingPackageNames(ancestor),
        );
      }

      // Check for Dart workspace (pubspec.yaml with workspace key).
      final rootPubspec = File(p.join(ancestor, 'pubspec.yaml'));
      if (rootPubspec.existsSync() && ancestor != projectPath) {
        try {
          final content = rootPubspec.readAsStringSync();
          if (content.contains('workspace:')) {
            return _MonorepoInfo(
              tool: 'dart_workspace',
              packages: _collectSiblingPackageNames(ancestor),
            );
          }
        } on FileSystemException {
          // ignore
        }
      }
    }

    return const _MonorepoInfo(tool: null, packages: []);
  }

  /// Collects the names of all pubspec.yaml-bearing packages under
  /// the monorepo root, excluding the current project.
  List<String> _collectSiblingPackageNames(String monorepoRoot) {
    final currentName = p.basename(projectPath);
    final names = <String>[];

    for (final container in ['apps', 'packages', 'modules']) {
      final dir = Directory(p.join(monorepoRoot, container));
      if (!dir.existsSync()) continue;

      try {
        for (final entity in dir.listSync()) {
          if (entity is! Directory) continue;
          final name = p.basename(entity.path);
          if (name == currentName || name.startsWith('.')) continue;
          if (File(p.join(entity.path, 'pubspec.yaml')).existsSync()) {
            names.add(name);
          }
        }
      } on FileSystemException {
        // permission errors — skip
      }
    }

    return names..sort();
  }

  /// Determines the top-level organization pattern.
  String _detectOrganization(
    List<String> topLevelDirs,
    List<String> featureDirs,
  ) {
    final hasFeatureContainer = topLevelDirs.any(
      (d) => const {'features', 'modules', 'feature', 'pages'}.contains(d),
    );
    final topLevelLayerCount = topLevelDirs
        .where((d) => _layerNames.contains(d))
        .length;
    final hasTopLevelLayers = topLevelLayerCount >= 2;

    if (hasFeatureContainer && hasTopLevelLayers) return 'hybrid';
    if (hasFeatureContainer) return 'feature-first';
    // Layer-first takes precedence when the top-level has 2+ layers,
    // even if features were found nested inside a layer.
    if (hasTopLevelLayers) return 'layer-first';
    if (featureDirs.length >= 2) return 'feature-first';

    return 'flat';
  }

  /// Detects the layer pattern (Clean Architecture layers, etc.).
  LayerPattern? _detectLayerPattern(
    Directory libDir,
    List<String> topLevelDirs,
    List<String> featureDirs,
  ) {
    // Check for layers at top level.
    final topLevelLayers = topLevelDirs
        .where((d) => _layerNames.contains(d))
        .toList();

    // Check for layers per-feature.
    final perFeature = _hasPerFeatureLayers(libDir, featureDirs);

    if (topLevelLayers.isEmpty && !perFeature) return null;

    final layers = perFeature
        ? _collectPerFeatureLayers(libDir, featureDirs)
        : topLevelLayers;

    final detected = _classifyArchitecture(layers);

    return LayerPattern(
      detected: detected,
      layers: layers,
      perFeature: perFeature,
    );
  }

  /// Checks if features have their own internal layer directories.
  bool _hasPerFeatureLayers(Directory libDir, List<String> featureDirs) {
    if (featureDirs.isEmpty) return false;

    // Find the feature container.
    final containers = ['features', 'modules', 'feature', 'pages'];
    Directory? featureParent;
    for (final name in containers) {
      final dir = Directory(p.join(libDir.path, name));
      if (dir.existsSync()) {
        featureParent = dir;
        break;
      }
    }
    featureParent ??= libDir;

    var featuresWithLayers = 0;
    for (final feature in featureDirs) {
      final featureDir = Directory(p.join(featureParent.path, feature));
      if (!featureDir.existsSync()) continue;

      final subdirs = FileUtils.listSubdirectories(featureDir);
      final layerCount = subdirs.where((d) => _layerNames.contains(d)).length;
      if (layerCount >= 2) featuresWithLayers++;
    }

    // Consider it per-feature if at least half the features have layers.
    return featureDirs.isNotEmpty &&
        featuresWithLayers >= (featureDirs.length / 2).ceil();
  }

  /// Collects the union of layer names across all feature directories.
  List<String> _collectPerFeatureLayers(
    Directory libDir,
    List<String> featureDirs,
  ) {
    final containers = ['features', 'modules', 'feature', 'pages'];
    Directory? featureParent;
    for (final name in containers) {
      final dir = Directory(p.join(libDir.path, name));
      if (dir.existsSync()) {
        featureParent = dir;
        break;
      }
    }
    featureParent ??= libDir;

    final allLayers = <String>{};
    for (final feature in featureDirs) {
      final featureDir = Directory(p.join(featureParent.path, feature));
      if (!featureDir.existsSync()) continue;

      final subdirs = FileUtils.listSubdirectories(featureDir);
      allLayers.addAll(subdirs.where((d) => _layerNames.contains(d)));
    }

    return allLayers.toList()..sort();
  }

  /// Classifies the architecture based on which layers are present.
  String _classifyArchitecture(List<String> layers) {
    final layerSet = layers.toSet();

    if (layerSet.containsAll(['data', 'domain', 'presentation']) ||
        layerSet.containsAll(['data', 'domain', 'ui'])) {
      return 'clean_architecture';
    }

    if (layerSet.containsAll(['model', 'view', 'viewmodel']) ||
        layerSet.containsAll(['model', 'view', 'view_model'])) {
      return 'mvvm';
    }

    if (layerSet.containsAll(['model', 'view', 'controller'])) {
      return 'mvc';
    }

    return 'layered';
  }
}

/// Internal result type for monorepo detection.
class _MonorepoInfo {
  const _MonorepoInfo({required this.tool, required this.packages});

  final String? tool;
  final List<String> packages;
}
