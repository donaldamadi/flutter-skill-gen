import 'dart:io';

import 'package:path/path.dart' as p;

import '../analyzers/code_sampler.dart';
import '../analyzers/domain_analyzer.dart';
import '../analyzers/pattern_detector.dart';
import '../analyzers/pubspec_analyzer.dart';
import '../analyzers/structure_analyzer.dart';
import '../generators/evidence_bundle_builder.dart';
import '../models/domain_facts.dart';
import '../models/evidence_bundle.dart';
import '../models/pattern_info.dart';
import '../models/project_facts.dart';
import '../models/structure_info.dart';
import '../utils/file_utils.dart';
import '../utils/logger.dart';

/// Orchestrates all analyzers to produce a complete [ProjectFacts]
/// for a Flutter project.
class ProjectScanner {
  /// Creates a [ProjectScanner] for the project at [projectPath].
  ProjectScanner({required this.projectPath, Logger? logger})
    : logger = logger ?? const Logger();

  /// Root path of the Flutter project to scan.
  final String projectPath;

  /// Logger for diagnostic output.
  final Logger logger;

  /// The tool version embedded in generated facts.
  static const toolVersion = '0.2.0';

  /// Scans the project and returns a [ProjectFacts] instance.
  ///
  /// Returns `null` if the project path doesn't exist or has no
  /// pubspec.yaml. For monorepo roots (no pubspec.yaml but contains
  /// `app/`, `packages/`, or `melos.yaml`), automatically resolves
  /// to the primary app package.
  ProjectFacts? scan() {
    final dir = Directory(projectPath);
    if (!dir.existsSync()) {
      logger.error('Project path does not exist: $projectPath');
      return null;
    }

    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      // Check if this is a monorepo root.
      final resolved = _resolveMonorepoRoot(projectPath);
      if (resolved != null) {
        logger.info(
          'Monorepo detected — scanning from: '
          '${p.basename(resolved)}',
        );
        return ProjectScanner(projectPath: resolved, logger: logger).scan();
      }
      logger.error('No pubspec.yaml found at: $projectPath');
      return null;
    }

    logger
      ..debug('Scanning project at: $projectPath')
      // Step 1: Analyze pubspec.yaml.
      ..debug('Analyzing pubspec.yaml...');
    final pubspecAnalyzer = PubspecAnalyzer(projectPath);
    if (!pubspecAnalyzer.load()) {
      logger.error('Failed to parse pubspec.yaml');
      return null;
    }
    final dependencies = pubspecAnalyzer.analyzeDependencies();

    // Step 2: Analyze folder structure.
    logger.debug('Analyzing folder structure...');
    final structureAnalyzer = StructureAnalyzer(projectPath);
    final structure = structureAnalyzer.analyze();

    // Step 3: Detect patterns.
    logger.debug('Detecting patterns...');
    final patternDetector = PatternDetector(
      dependencies: dependencies,
      structure: structure,
      projectPath: projectPath,
    );
    final patterns = patternDetector.detect();

    // Step 4: Sample code conventions.
    logger.debug('Sampling code conventions...');
    final codeSampler = CodeSampler(projectPath);
    final conventions = codeSampler.analyze();

    // Step 5: Analyze testing setup.
    logger.debug('Analyzing test structure...');
    final testing = _analyzeTests();

    // Step 6: Compute complexity metrics.
    logger.debug('Computing complexity...');
    final complexity = _computeComplexity(structure);

    // Step 7: Build the evidence bundle — ground truth for AI
    // generation and draft verification.
    logger.debug('Building evidence bundle...');
    final evidence = _buildEvidenceBundle(
      projectName: pubspecAnalyzer.projectName,
      structure: structure,
      structureAnalyzer: structureAnalyzer,
      patterns: patterns,
    );

    return ProjectFacts(
      projectName: pubspecAnalyzer.projectName,
      projectDescription: pubspecAnalyzer.projectDescription,
      flutterSdk: pubspecAnalyzer.flutterSdk,
      dartSdk: pubspecAnalyzer.dartSdk,
      dependencies: dependencies,
      structure: structure,
      patterns: patterns,
      conventions: conventions,
      testing: testing,
      complexity: complexity,
      evidence: evidence,
      generatedAt: DateTime.now().toUtc().toIso8601String(),
      toolVersion: toolVersion,
    );
  }

  // ---------------------------------------------------------------------------
  // Evidence bundle
  // ---------------------------------------------------------------------------

  /// Runs [DomainAnalyzer] against every detected feature, collects
  /// the lib/ file + class manifest, and assembles an [EvidenceBundle]
  /// via [EvidenceBundleBuilder]. Coverage is exhaustive (not limited
  /// to the split-mode recommendation) so the verifier has ground
  /// truth for every feature regardless of output mode.
  EvidenceBundle _buildEvidenceBundle({
    required String projectName,
    required StructureInfo structure,
    required StructureAnalyzer structureAnalyzer,
    required PatternInfo patterns,
  }) {
    final domainAnalyzer = DomainAnalyzer(projectPath);
    final allDomainFacts = <DomainFacts>[
      for (final feature in structure.featureDirs)
        domainAnalyzer.analyze(feature, structure),
    ];
    final featureBreakdown = structureAnalyzer.analyzeFeatureBreakdown(
      structure.featureDirs,
    );
    final manifest = _extractLibManifest();

    return const EvidenceBundleBuilder().build(
      projectName: projectName,
      domainFacts: allDomainFacts,
      featureBreakdown: featureBreakdown,
      allFilePaths: manifest.filePaths,
      allClassNames: manifest.classNames,
      diStyle: patterns.di,
    );
  }

  /// Walks `lib/` and returns the full set of relative file paths plus
  /// every top-level class name declared within. Used as the verifier's
  /// lookup table.
  _LibManifest _extractLibManifest() {
    final libDir = Directory(p.join(projectPath, 'lib'));
    if (!libDir.existsSync()) {
      return const _LibManifest(filePaths: [], classNames: []);
    }

    final dartFiles = FileUtils.collectDartFiles(libDir);
    final filePaths = <String>[];
    final classNames = <String>{};

    for (final file in dartFiles) {
      filePaths.add(p.relative(file.path, from: projectPath));
      final content = _readFileSafe(file);
      if (content == null) continue;
      for (final match in _classDeclPattern.allMatches(content)) {
        final name = match.group(1);
        if (name == null) continue;
        if (name.startsWith('_')) continue;
        if (name.startsWith(r'$')) continue;
        classNames.add(name);
      }
    }

    filePaths.sort();
    return _LibManifest(
      filePaths: filePaths,
      classNames: (classNames.toList()..sort()),
    );
  }

  static final RegExp _classDeclPattern = RegExp(
    r'(?:abstract\s+|sealed\s+|final\s+|base\s+|interface\s+|mixin\s+)?'
    r'class\s+(\w+)',
  );

  // ---------------------------------------------------------------------------
  // Testing analysis
  // ---------------------------------------------------------------------------

  TestingInfo _analyzeTests() {
    final testDir = Directory(p.join(projectPath, 'test'));
    final integrationTestDir = Directory(
      p.join(projectPath, 'integration_test'),
    );

    final hasTestDir = testDir.existsSync();
    final hasIntegrationDir = integrationTestDir.existsSync();

    if (!hasTestDir && !hasIntegrationDir) {
      return const TestingInfo();
    }

    var hasUnitTests = false;
    var hasWidgetTests = false;

    if (hasTestDir) {
      final testFiles = FileUtils.collectDartFiles(testDir);
      for (final file in testFiles) {
        final content = _readFileSafe(file);
        if (content == null) continue;

        if (content.contains('testWidgets(') ||
            content.contains('pumpWidget(')) {
          hasWidgetTests = true;
        } else if (content.contains('test(') || content.contains('group(')) {
          hasUnitTests = true;
        }

        if (hasUnitTests && hasWidgetTests) break;
      }
    }

    final mockingLibrary = _detectMockingLibrary();
    final testStructure = _detectTestStructure(testDir);

    return TestingInfo(
      hasUnitTests: hasUnitTests,
      hasWidgetTests: hasWidgetTests,
      hasIntegrationTests: hasIntegrationDir,
      mockingLibrary: mockingLibrary,
      testStructure: testStructure,
    );
  }

  String? _detectMockingLibrary() {
    final pubspecAnalyzer = PubspecAnalyzer(projectPath);
    if (!pubspecAnalyzer.load()) return null;

    final allDeps = pubspecAnalyzer.allDependencyNames;
    if (allDeps.contains('mocktail')) return 'mocktail';
    if (allDeps.contains('mockito')) return 'mockito';
    return null;
  }

  String? _detectTestStructure(Directory testDir) {
    if (!testDir.existsSync()) return null;

    final testSubdirs = FileUtils.listSubdirectories(testDir);
    final libDir = Directory(p.join(projectPath, 'lib'));
    if (!libDir.existsSync()) return null;

    final libSubdirs = FileUtils.listSubdirectories(libDir);

    // Check if test directory mirrors lib directory.
    final overlap = testSubdirs.where(libSubdirs.contains).length;
    if (overlap >= 2 ||
        (libSubdirs.isNotEmpty && overlap == libSubdirs.length)) {
      return 'mirrors_lib';
    }

    if (testSubdirs.length <= 1) return 'flat';

    return 'custom';
  }

  // ---------------------------------------------------------------------------
  // Complexity computation
  // ---------------------------------------------------------------------------

  ComplexityInfo _computeComplexity(StructureInfo structure) {
    final libDir = Directory(p.join(projectPath, 'lib'));
    final dartFiles = libDir.existsSync()
        ? FileUtils.collectDartFiles(libDir)
        : <File>[];
    final totalDartFiles = dartFiles.length;
    final totalFeatures = structure.featureDirs.length;

    final magnitude = _estimateMagnitude(totalDartFiles, totalFeatures);
    final recommendedSkillFiles = _recommendSkillFiles(
      totalDartFiles,
      totalFeatures,
      structure,
    );

    return ComplexityInfo(
      totalDartFiles: totalDartFiles,
      totalFeatures: totalFeatures,
      estimatedMagnitude: magnitude,
      recommendedSkillFiles: recommendedSkillFiles,
    );
  }

  String _estimateMagnitude(int dartFiles, int features) {
    if (dartFiles > 200 || features > 8) return 'large';
    if (dartFiles > 50 || features > 3) return 'medium';
    return 'small';
  }

  List<String> _recommendSkillFiles(
    int dartFiles,
    int features,
    StructureInfo structure,
  ) {
    // Small projects: single skill file.
    if (dartFiles <= 50 && features <= 3) return ['core'];

    final recommended = ['core'];

    // Add feature-specific skills for large projects.
    if (features > 3) {
      recommended.addAll(structure.featureDirs.take(5));
    }

    // Always recommend data skill for projects with networking.
    if (dartFiles > 50) {
      recommended.add('data');
    }

    return recommended;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Checks if [path] is a monorepo root and returns the path to
  /// the primary app package, or `null` if not a monorepo.
  ///
  /// Looks for:
  /// 1. `app/pubspec.yaml` (common convention)
  /// 2. `melos.yaml` or root pubspec with `workspace:` — then
  ///    picks the first directory under `apps/` or falls back to
  ///    the first package found.
  String? _resolveMonorepoRoot(String path) {
    // Direct app/ directory with a pubspec.
    final appDir = Directory(p.join(path, 'app'));
    if (File(p.join(appDir.path, 'pubspec.yaml')).existsSync()) {
      return appDir.path;
    }

    // apps/ directory (Melos convention).
    final appsDir = Directory(p.join(path, 'apps'));
    if (appsDir.existsSync()) {
      final app = _firstPackageIn(appsDir);
      if (app != null) return app;
    }

    // packages/ directory — fall back to first package.
    final packagesDir = Directory(p.join(path, 'packages'));
    if (packagesDir.existsSync()) {
      final pkg = _firstPackageIn(packagesDir);
      if (pkg != null) return pkg;
    }

    return null;
  }

  /// Returns the path to the first subdirectory of [dir] that
  /// contains a `pubspec.yaml`.
  String? _firstPackageIn(Directory dir) {
    try {
      final entries = dir.listSync().whereType<Directory>();
      for (final sub in entries) {
        if (File(p.join(sub.path, 'pubspec.yaml')).existsSync()) {
          return sub.path;
        }
      }
    } on FileSystemException {
      // Ignore permission errors.
    }
    return null;
  }

  String? _readFileSafe(File file) {
    try {
      return file.readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }
}

/// Internal result type for [ProjectScanner._extractLibManifest].
class _LibManifest {
  const _LibManifest({required this.filePaths, required this.classNames});

  final List<String> filePaths;
  final List<String> classNames;
}
