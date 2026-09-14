import 'dart:io';

import 'package:flutter_skill_gen/src/utils/file_utils.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'flutter_skill_gen_file_utils_test_',
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  void write(String relativePath, [String content = 'class X {}']) {
    final file = File('${tempDir.path}/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  group('collectDartFiles', () {
    test('returns files sorted by path regardless of creation order', () {
      // Created deliberately out of order: listSync returns
      // filesystem order, so an unsorted implementation would hand
      // back zebra/ before alpha/ here.
      write('lib/zebra/z.dart');
      write('lib/alpha/a.dart');
      write('lib/middle/m.dart');

      final paths = FileUtils.collectDartFiles(
        tempDir,
      ).map((f) => f.path.replaceFirst('${tempDir.path}/', '')).toList();

      expect(paths, [
        'lib/alpha/a.dart',
        'lib/middle/m.dart',
        'lib/zebra/z.dart',
      ]);
    });

    test('is stable across repeated calls', () {
      write('lib/b/b.dart');
      write('lib/a/a.dart');
      write('lib/c/c.dart');

      final first = FileUtils.collectDartFiles(tempDir).map((f) => f.path);
      final second = FileUtils.collectDartFiles(tempDir).map((f) => f.path);

      expect(first, second);
    });

    test('excludes generated files', () {
      write('lib/model.dart');
      write('lib/model.g.dart');
      write('lib/model.freezed.dart');

      final names = FileUtils.collectDartFiles(
        tempDir,
      ).map((f) => f.uri.pathSegments.last);

      expect(names, ['model.dart']);
    });

    test('returns empty for a missing directory', () {
      expect(
        FileUtils.collectDartFiles(Directory('${tempDir.path}/nope')),
        isEmpty,
      );
    });
  });
}
