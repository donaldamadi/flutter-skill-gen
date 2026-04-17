import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/convention_info.dart';
import '../models/domain_facts.dart';
import '../models/structure_info.dart';
import '../utils/file_utils.dart';

/// Analyzes a single feature/domain directory within a Flutter project
/// to produce [DomainFacts] for domain-specific skill generation.
class DomainAnalyzer {
  /// Creates a [DomainAnalyzer] for [projectPath].
  DomainAnalyzer(this.projectPath);

  /// Root path of the Flutter project.
  final String projectPath;

  /// Well-known layer directory names.
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
    'service',
    'services',
    'usecase',
    'usecases',
    'use_case',
    'use_cases',
    'entity',
    'entities',
  };

  /// Regex for extracting class declarations.
  static final _classPattern = RegExp(
    r'(?:abstract\s+|sealed\s+)?class\s+(\w+)',
  );

  /// Analyzes the given [domainName] and returns [DomainFacts].
  ///
  /// The [structure] is used to locate the domain's directory based
  /// on the project's organization pattern.
  DomainFacts analyze(String domainName, StructureInfo structure) {
    final domainDir = _findDomainDirectory(domainName, structure);
    if (domainDir == null || !domainDir.existsSync()) {
      return DomainFacts(domainName: domainName);
    }

    final dartFiles = FileUtils.collectDartFiles(domainDir);
    final relativeFiles = dartFiles
        .map((f) => p.relative(f.path, from: projectPath))
        .toList();

    final layers = _detectLayers(domainDir);
    final stateClasses = _detectStateClasses(dartFiles);
    final entities = _detectEntities(dartFiles);
    final samples = _collectSamples(dartFiles);

    return DomainFacts(
      domainName: domainName,
      files: relativeFiles,
      samples: samples,
      layers: layers,
      stateClasses: stateClasses,
      entities: entities,
    );
  }

  /// Locates the directory for [domainName] based on project structure.
  Directory? _findDomainDirectory(String domainName, StructureInfo structure) {
    final libDir = p.join(projectPath, 'lib');

    // Special case: "data" domain maps to the data layer directory.
    if (domainName == 'data') {
      final dataDir = Directory(p.join(libDir, 'data'));
      if (dataDir.existsSync()) return dataDir;
    }

    // Check for explicit feature containers.
    const featureContainers = ['features', 'modules', 'feature', 'pages'];
    for (final container in featureContainers) {
      final dir = Directory(p.join(libDir, container, domainName));
      if (dir.existsSync()) return dir;
    }

    // Check for layer-first nested features.
    const presentationSubContainers = [
      'presentation/pages',
      'presentation/features',
      'presentation/screens',
      'ui/pages',
      'ui/features',
      'ui/screens',
    ];
    for (final sub in presentationSubContainers) {
      final dir = Directory(p.join(libDir, sub, domainName));
      if (dir.existsSync()) return dir;
    }

    // Fallback: direct top-level directory.
    final topLevel = Directory(p.join(libDir, domainName));
    if (topLevel.existsSync()) return topLevel;

    return null;
  }

  /// Detects which architectural layers exist in this domain.
  List<String> _detectLayers(Directory domainDir) {
    final subdirs = FileUtils.listSubdirectories(domainDir);
    return subdirs.where((d) => _layerNames.contains(d)).toList()..sort();
  }

  /// Detects BLoC/Cubit/Notifier class names from file content.
  List<String> _detectStateClasses(List<File> files) {
    final classes = <String>[];

    for (final file in files) {
      final name = p.basename(file.path).toLowerCase();
      if (!name.endsWith('_bloc.dart') &&
          !name.endsWith('_cubit.dart') &&
          !name.endsWith('_notifier.dart') &&
          !name.endsWith('_state.dart') &&
          !name.endsWith('_event.dart')) {
        continue;
      }

      final content = _readFileSafe(file);
      if (content == null) continue;

      for (final match in _classPattern.allMatches(content)) {
        final className = match.group(1)!;
        if (className.endsWith('Bloc') ||
            className.endsWith('Cubit') ||
            className.endsWith('Notifier') ||
            className.endsWith('State') ||
            className.endsWith('Event')) {
          classes.add(className);
        }
      }
    }

    return classes..sort();
  }

  /// Detects entity/model class names from files in data/domain layers.
  List<String> _detectEntities(List<File> files) {
    final entities = <String>[];

    for (final file in files) {
      final relativePath = p.relative(file.path, from: projectPath);
      final isInModelLayer =
          relativePath.contains('data/') ||
          relativePath.contains('domain/') ||
          relativePath.contains('models/') ||
          relativePath.contains('model/') ||
          relativePath.contains('entities/') ||
          relativePath.contains('entity/');
      if (!isInModelLayer) continue;

      final name = p.basename(file.path).toLowerCase();
      if (name.endsWith('_test.dart')) continue;
      if (!name.contains('model') &&
          !name.contains('dto') &&
          !name.contains('entity') &&
          !name.contains('response') &&
          !name.contains('request')) {
        continue;
      }

      final content = _readFileSafe(file);
      if (content == null) continue;

      for (final match in _classPattern.allMatches(content)) {
        final className = match.group(1)!;
        // Skip generated helpers and private classes.
        if (className.startsWith('_')) continue;
        if (className.startsWith(r'$')) continue;
        entities.add(className);
      }
    }

    return entities..sort();
  }

  /// Collects up to 3 representative code samples from domain files.
  List<CodeSample> _collectSamples(List<File> files) {
    final samples = <CodeSample>[];

    for (final file in files) {
      final name = p.basename(file.path).toLowerCase();
      final relativePath = p.relative(file.path, from: projectPath);

      final type = _classifySampleType(name, relativePath);
      if (type == null) continue;
      if (samples.any((s) => s.type == type)) continue;

      final content = _readFileSafe(file);
      if (content == null) continue;

      final snippet = _extractSnippet(content);
      if (snippet.isEmpty) continue;

      samples.add(CodeSample(type: type, file: relativePath, snippet: snippet));

      if (samples.length >= 3) break;
    }

    return samples;
  }

  String? _classifySampleType(String fileName, String relativePath) {
    if (fileName.endsWith('_bloc.dart')) return 'bloc_example';
    if (fileName.endsWith('_cubit.dart')) return 'cubit_example';
    if (fileName.endsWith('_notifier.dart')) return 'notifier_example';
    if (fileName.endsWith('_repository_impl.dart') ||
        fileName.endsWith('_repository.dart')) {
      return 'repository_example';
    }
    if (fileName.endsWith('_usecase.dart') ||
        fileName.endsWith('_use_case.dart')) {
      return 'usecase_example';
    }
    if (fileName.endsWith('_screen.dart') ||
        fileName.endsWith('_page.dart') ||
        fileName.endsWith('_view.dart')) {
      return 'screen_example';
    }
    if (fileName.contains('model') ||
        fileName.contains('dto') ||
        fileName.contains('entity')) {
      return 'model_example';
    }
    return null;
  }

  /// Extracts a snippet from the first class declaration, max 30 lines.
  String _extractSnippet(String content) {
    const maxLines = 30;
    final lines = content.split('\n');

    var classStart = -1;
    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trimLeft();
      if (trimmed.startsWith('class ') ||
          trimmed.startsWith('abstract class ') ||
          trimmed.startsWith('sealed class ') ||
          trimmed.startsWith('mixin ')) {
        classStart = i;
        break;
      }
    }

    if (classStart == -1) {
      return lines.take(maxLines).join('\n').trim();
    }

    final end = (classStart + maxLines).clamp(0, lines.length);
    return lines.sublist(classStart, end).join('\n').trim();
  }

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
