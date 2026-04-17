import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../models/convention_info.dart';
import '../utils/file_utils.dart';

/// Extracts representative code samples and detects naming/import
/// conventions from a Flutter project's source files.
class CodeSampler {
  /// Creates a [CodeSampler] for the project at [projectPath].
  CodeSampler(this.projectPath);

  /// Root path of the Flutter project to analyze.
  final String projectPath;

  /// Maximum lines to include in a code snippet.
  static const _maxSnippetLines = 40;

  /// Maximum number of files to scan for convention detection.
  static const _maxFilesToScan = 100;

  /// Analyzes source files and returns a [ConventionInfo].
  ConventionInfo analyze() {
    final libDir = Directory(p.join(projectPath, 'lib'));
    if (!libDir.existsSync()) {
      return const ConventionInfo();
    }

    final dartFiles = FileUtils.collectDartFiles(libDir);
    final filesToScan = dartFiles.take(_maxFilesToScan).toList();

    return ConventionInfo(
      naming: _detectNaming(filesToScan),
      imports: _detectImports(filesToScan),
      samples: _collectSamples(filesToScan),
    );
  }

  // ---------------------------------------------------------------------------
  // Naming convention detection
  // ---------------------------------------------------------------------------

  NamingConvention _detectNaming(List<File> files) {
    final fileNames = files
        .map((f) => p.basenameWithoutExtension(f.path))
        .toList();
    final fileStyle = _detectNamingStyle(fileNames);

    String? blocEvents;
    String? blocStates;
    var hasBlocFiles = false;
    var hasCubitFiles = false;

    for (final file in files) {
      final name = p.basename(file.path).toLowerCase();
      if (name.endsWith('_bloc.dart')) hasBlocFiles = true;
      if (name.endsWith('_cubit.dart')) hasCubitFiles = true;

      if (!_isBlocFile(file.path)) continue;
      final content = _readFileSafe(file);
      if (content == null) continue;

      blocEvents ??= _detectBlocEventNaming(content);
      blocStates ??= _detectBlocStateNaming(content);

      if (blocEvents != null && blocStates != null) break;
    }

    String? stateStyle;
    if (hasBlocFiles && hasCubitFiles) {
      stateStyle = 'mixed';
    } else if (hasCubitFiles) {
      stateStyle = 'cubit_only';
    } else if (hasBlocFiles) {
      stateStyle = 'bloc';
    }

    return NamingConvention(
      files: fileStyle,
      classes: 'PascalCase',
      blocEvents: blocEvents,
      blocStates: blocStates,
      stateStyle: stateStyle,
    );
  }

  String _detectNamingStyle(List<String> names) {
    if (names.isEmpty) return 'snake_case';

    var snakeCount = 0;
    var camelCount = 0;

    for (final name in names) {
      if (name.contains('_')) {
        snakeCount++;
      } else if (name != name.toLowerCase() && !name.contains('_')) {
        camelCount++;
      } else {
        snakeCount++;
      }
    }

    return snakeCount >= camelCount ? 'snake_case' : 'camelCase';
  }

  bool _isBlocFile(String path) {
    final name = p.basename(path).toLowerCase();
    return name.endsWith('_bloc.dart') ||
        name.endsWith('_event.dart') ||
        name.endsWith('_state.dart') ||
        name.endsWith('_cubit.dart');
  }

  String? _detectBlocEventNaming(String content) {
    final eventClassPattern = RegExp(r'class\s+(\w+Event)\s');
    final match = eventClassPattern.firstMatch(content);
    if (match != null) return 'PascalCase_suffixed_Event';

    final sealedEventPattern = RegExp(r'sealed\s+class\s+\w+Event\b');
    if (sealedEventPattern.hasMatch(content)) {
      return 'PascalCase_suffixed_Event';
    }

    return null;
  }

  String? _detectBlocStateNaming(String content) {
    final stateClassPattern = RegExp(r'class\s+(\w+State)\s');
    final match = stateClassPattern.firstMatch(content);
    if (match != null) return 'PascalCase_suffixed_State';

    final sealedStatePattern = RegExp(r'sealed\s+class\s+\w+State\b');
    if (sealedStatePattern.hasMatch(content)) {
      return 'PascalCase_suffixed_State';
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Import convention detection
  // ---------------------------------------------------------------------------

  ImportConvention _detectImports(List<File> files) {
    var relativeCount = 0;
    var packageCount = 0;
    var barrelFileCount = 0;

    for (final file in files) {
      final content = _readFileSafe(file);
      if (content == null) continue;

      final lines = content.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith("import '") || trimmed.startsWith('import "')) {
          if (trimmed.contains('package:')) {
            packageCount++;
          } else if (trimmed.startsWith("import '../") ||
              trimmed.startsWith("import './") ||
              trimmed.startsWith('import "../') ||
              trimmed.startsWith('import "./')) {
            relativeCount++;
          }
        }

        if (trimmed.startsWith('export ')) {
          barrelFileCount++;
        }
      }
    }

    String style;
    if (relativeCount > 0 && packageCount > 0) {
      style = relativeCount > packageCount ? 'relative' : 'package';
    } else if (relativeCount > 0) {
      style = 'relative';
    } else {
      style = 'package';
    }

    return ImportConvention(style: style, barrelFiles: barrelFileCount >= 3);
  }

  // ---------------------------------------------------------------------------
  // Code sample collection
  // ---------------------------------------------------------------------------

  List<CodeSample> _collectSamples(List<File> files) {
    final samples = <CodeSample>[];

    for (final file in files) {
      final relativePath = p.relative(file.path, from: projectPath);
      final name = p.basename(file.path).toLowerCase();

      final type = _classifySampleType(name, relativePath);
      if (type == null) continue;

      // Skip if we already have a sample of this type.
      if (samples.any((s) => s.type == type)) continue;

      final content = _readFileSafe(file);
      if (content == null) continue;

      final snippet = _extractSnippet(content);
      if (snippet.isEmpty) continue;

      samples.add(CodeSample(type: type, file: relativePath, snippet: snippet));

      // Cap at 5 samples to keep output manageable.
      if (samples.length >= 5) break;
    }

    return samples;
  }

  String? _classifySampleType(String fileName, String relativePath) {
    if (fileName.endsWith('_bloc.dart')) return 'bloc_example';
    if (fileName.endsWith('_cubit.dart')) return 'cubit_example';
    if (fileName.endsWith('_notifier.dart')) return 'notifier_example';
    if (fileName.endsWith('_controller.dart')) return 'controller_example';

    if (fileName.endsWith('_repository_impl.dart') ||
        fileName.endsWith('_repository.dart')) {
      return 'repository_example';
    }

    if (fileName.endsWith('_usecase.dart') ||
        fileName.endsWith('_use_case.dart')) {
      return 'usecase_example';
    }

    // Model detection: require the file to be inside a data/, domain/, or
    // models/ directory to avoid misclassifying utility files that happen
    // to have "model" in the filename (e.g. l10n_model.dart in utils/).
    final isInModelDir =
        relativePath.contains('data/') ||
        relativePath.contains('domain/') ||
        relativePath.contains('models/') ||
        relativePath.contains('model/') ||
        relativePath.contains('entities/') ||
        relativePath.contains('entity/');
    if (isInModelDir &&
        !fileName.endsWith('_test.dart') &&
        (fileName.contains('model') ||
            fileName.contains('dto') ||
            fileName.contains('entity') ||
            fileName.contains('response') ||
            fileName.contains('request'))) {
      return 'model_example';
    }

    // Screen detection: require the file to be inside a feature
    // directory (presentation/pages/screens/ui), not core/widgets
    // which are reusable components, not screens.
    final isInFeature =
        relativePath.contains('features/') ||
        relativePath.contains('presentation/') ||
        relativePath.contains('pages/') ||
        relativePath.contains('screens/');
    final isInCoreWidgets = relativePath.contains('core/widget');

    if (isInFeature && !isInCoreWidgets) {
      if (fileName.endsWith('_screen.dart') ||
          fileName.endsWith('_page.dart') ||
          fileName.endsWith('_view.dart')) {
        return 'screen_example';
      }
    }

    return null;
  }

  /// Extracts a meaningful snippet from file content.
  ///
  /// Prefers the first class declaration, falling back to the full file
  /// (truncated to [_maxSnippetLines]).
  String _extractSnippet(String content) {
    final lines = content.split('\n');

    // Find the first class/mixin/enum declaration.
    var classStart = -1;
    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trimLeft();
      if (trimmed.startsWith('class ') ||
          trimmed.startsWith('abstract class ') ||
          trimmed.startsWith('sealed class ') ||
          trimmed.startsWith('mixin ') ||
          trimmed.startsWith('enum ')) {
        classStart = i;
        break;
      }
    }

    if (classStart == -1) {
      return lines.take(_maxSnippetLines).join('\n').trim();
    }

    // Include up to _maxSnippetLines from the class declaration.
    final end = min(classStart + _maxSnippetLines, lines.length);
    return lines.sublist(classStart, end).join('\n').trim();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String? _readFileSafe(File file) {
    try {
      return file.readAsStringSync();
    } on FileSystemException {
      return null;
    } on FormatException {
      // Binary or non-UTF-8 content in a .dart file.
      return null;
    }
  }
}
