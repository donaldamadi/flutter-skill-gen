import 'dart:io';

import 'package:flutter_skill_gen/src/router/manifest_reader.dart';
import 'package:test/test.dart';

void main() {
  group('ManifestReader', () {
    late Directory tempDir;
    late ManifestReader reader;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'flutter_skill_gen_manifest_reader_test_',
      );
      reader = ManifestReader(projectPath: tempDir.path);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('manifestPath points to .skill_manifest.yaml', () {
      expect(reader.manifestPath, endsWith('.skill_manifest.yaml'));
    });

    test('exists returns false when no manifest', () {
      expect(reader.exists, isFalse);
    });

    test('exists returns true when manifest present', () {
      File(
        reader.manifestPath,
      ).writeAsStringSync('skills:\n  - file: SKILL.md\n    scope: []\n');
      expect(reader.exists, isTrue);
    });

    test('read returns empty list when no file', () {
      expect(reader.read(), isEmpty);
    });

    test('read returns empty list for corrupt YAML', () {
      File(reader.manifestPath).writeAsStringSync('key: [unclosed');
      expect(reader.read(), isEmpty);
    });

    test('read returns empty list when root is not a map', () {
      File(reader.manifestPath).writeAsStringSync('- just a list\n');
      expect(reader.read(), isEmpty);
    });

    test('read returns empty list when skills key is missing', () {
      File(reader.manifestPath).writeAsStringSync('other_key: value\n');
      expect(reader.read(), isEmpty);
    });

    test('read parses single skill entry', () {
      File(reader.manifestPath).writeAsStringSync('''
skills:
  - file: SKILL.md
    scope:
      - architecture
      - conventions
    always_inject: true
''');

      final entries = reader.read();
      expect(entries, hasLength(1));
      expect(entries[0].file, 'SKILL.md');
      expect(entries[0].scope, containsAll(['architecture', 'conventions']));
      expect(entries[0].alwaysInject, isTrue);
    });

    test('read parses multiple skill entries', () {
      File(reader.manifestPath).writeAsStringSync('''
skills:
  - file: SKILL.md
    scope:
      - architecture
    always_inject: true
  - file: SKILL_auth.md
    scope:
      - authentication
      - login
    inject_when: prompt mentions auth features
''');

      final entries = reader.read();
      expect(entries, hasLength(2));
      expect(entries[1].file, 'SKILL_auth.md');
      expect(entries[1].alwaysInject, isFalse);
      expect(entries[1].injectWhen, 'prompt mentions auth features');
    });

    test('read skips entries without file key', () {
      File(reader.manifestPath).writeAsStringSync('''
skills:
  - scope:
      - orphan
  - file: SKILL.md
    scope: []
''');

      final entries = reader.read();
      expect(entries, hasLength(1));
      expect(entries[0].file, 'SKILL.md');
    });

    test('read defaults alwaysInject to false', () {
      File(reader.manifestPath).writeAsStringSync('''
skills:
  - file: SKILL_auth.md
    scope:
      - auth
''');

      final entries = reader.read();
      expect(entries[0].alwaysInject, isFalse);
    });

    group('alwaysInjected', () {
      test('returns only entries with always_inject true', () {
        File(reader.manifestPath).writeAsStringSync('''
skills:
  - file: SKILL.md
    scope: []
    always_inject: true
  - file: SKILL_auth.md
    scope:
      - auth
  - file: SKILL_core.md
    scope: []
    always_inject: true
''');

        final always = reader.alwaysInjected();
        expect(always, hasLength(2));
        expect(
          always.map((e) => e.file),
          containsAll(['SKILL.md', 'SKILL_core.md']),
        );
      });
    });

    group('matchingScope', () {
      setUp(() {
        File(reader.manifestPath).writeAsStringSync('''
skills:
  - file: SKILL.md
    scope:
      - architecture
    always_inject: true
  - file: SKILL_auth.md
    scope:
      - authentication
      - login
  - file: SKILL_cart.md
    scope:
      - cart
      - checkout
''');
      });

      test('always includes always_inject entries', () {
        final entries = reader.matchingScope({'random'});
        expect(entries, hasLength(1));
        expect(entries[0].file, 'SKILL.md');
      });

      test('matches scope keywords case-insensitively', () {
        final entries = reader.matchingScope({'LOGIN'});
        expect(entries, hasLength(2)); // SKILL.md + auth
        expect(entries.map((e) => e.file).toList(), contains('SKILL_auth.md'));
      });

      test('matches multiple scopes', () {
        final entries = reader.matchingScope({'authentication', 'checkout'});
        expect(entries, hasLength(3)); // SKILL.md + auth + cart
      });

      test('returns only always_inject for empty keywords', () {
        final entries = reader.matchingScope(<String>{});
        expect(entries, hasLength(1));
        expect(entries[0].file, 'SKILL.md');
      });
    });
  });
}
