import 'dart:io';

import 'package:path/path.dart' as p;

/// Copies the named fixture project into [destination] and returns the
/// path of the copy.
///
/// The `prompt` and `assemble` commands write into the project they
/// are pointed at, so they are exercised against a throwaway copy
/// rather than the checked-in fixture.
String copyFixture(String fixtureName, String destination) {
  final source = Directory(p.join('test', 'fixtures', fixtureName));
  if (!source.existsSync()) {
    throw StateError('No fixture at ${source.path}');
  }

  final target = Directory(p.join(destination, fixtureName))
    ..createSync(recursive: true);

  for (final entity in source.listSync(recursive: true)) {
    final relative = p.relative(entity.path, from: source.path);
    final destinationPath = p.join(target.path, relative);
    if (entity is Directory) {
      Directory(destinationPath).createSync(recursive: true);
    } else if (entity is File) {
      File(destinationPath)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(entity.readAsBytesSync());
    }
  }

  return target.path;
}
