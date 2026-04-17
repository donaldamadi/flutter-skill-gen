import 'dart:io';

import 'package:yaml/yaml.dart';

/// Utility functions for YAML parsing.
class YamlUtils {
  const YamlUtils._();

  /// Loads and parses a YAML file, returning null if it doesn't exist.
  static YamlMap? loadYamlFile(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;

    try {
      final content = file.readAsStringSync();
      final doc = loadYaml(content);
      if (doc is YamlMap) return doc;
      return null;
    } on YamlException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  /// Safely extracts a string value from a [YamlMap].
  static String? getString(YamlMap map, String key) {
    final value = map[key];
    return value is String ? value : value?.toString();
  }

  /// Safely extracts a map from a [YamlMap].
  static YamlMap? getMap(YamlMap map, String key) {
    final value = map[key];
    return value is YamlMap ? value : null;
  }

  /// Extracts all keys from a [YamlMap] section as a string list.
  static List<String> getKeys(YamlMap map, String key) {
    final section = map[key];
    if (section is YamlMap) {
      return section.keys.cast<String>().toList();
    }
    return [];
  }
}
