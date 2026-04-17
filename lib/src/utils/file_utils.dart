import 'dart:io';

import 'package:path/path.dart' as p;

/// Utility functions for file system operations.
class FileUtils {
  const FileUtils._();

  /// Collects all `.dart` files under [directory] recursively.
  ///
  /// Excludes generated files (`.g.dart`, `.freezed.dart`) and
  /// build artifacts (`.dart_tool/`, `build/`).
  static List<File> collectDartFiles(Directory directory) {
    if (!directory.existsSync()) return [];

    final files = <File>[];
    try {
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File) continue;
        final relativePath = p.relative(entity.path, from: directory.path);

        if (!entity.path.endsWith('.dart')) continue;
        if (_isGenerated(entity.path)) continue;
        if (_isExcludedDir(relativePath)) continue;

        files.add(entity);
      }
    } on FileSystemException {
      // Broken symlinks, permission errors, or other I/O issues —
      // return whatever was collected so far.
    }
    return files;
  }

  /// Returns the immediate subdirectory names of [directory].
  static List<String> listSubdirectories(Directory directory) {
    if (!directory.existsSync()) return [];

    try {
      return directory
          .listSync()
          .whereType<Directory>()
          .map((d) => p.basename(d.path))
          .where((name) => !name.startsWith('.'))
          .toList()
        ..sort();
    } on FileSystemException {
      return [];
    }
  }

  /// Reads a file's content, returning null if it doesn't exist or fails.
  static String? readFileOrNull(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return null;
    try {
      return file.readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  static bool _isGenerated(String path) =>
      path.endsWith('.g.dart') ||
      path.endsWith('.freezed.dart') ||
      path.endsWith('.gen.dart') ||
      path.endsWith('.config.dart') ||
      path.endsWith('.gr.dart');

  static bool _isExcludedDir(String relativePath) {
    final parts = p.split(relativePath);
    return parts.any(
      (part) => const {
        '.dart_tool',
        'build',
        '.symlinks',
        'generated',
        'generated_plugin_registrant',
      }.contains(part),
    );
  }
}
