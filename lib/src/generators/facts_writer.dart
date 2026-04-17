import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/project_facts.dart';

/// Writes [ProjectFacts] to a `.skill_facts.json` file.
class FactsWriter {
  const FactsWriter._();

  /// The default output file name.
  static const defaultFileName = '.skill_facts.json';

  /// Writes [facts] as formatted JSON to
  /// `[outputDir]/.skill_facts.json`.
  ///
  /// Returns the absolute path of the written file.
  static String write(ProjectFacts facts, {required String outputDir}) {
    final json = const JsonEncoder.withIndent('  ').convert(facts.toJson());
    final outputPath = p.join(outputDir, defaultFileName);
    final file = File(outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('$json\n');
    return outputPath;
  }
}
