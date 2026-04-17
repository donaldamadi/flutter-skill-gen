import 'dart:io';

import 'package:flutter_skill_gen/src/router/manifest_reader.dart';
import 'package:flutter_skill_gen/src/router/skill_router.dart';
import 'package:test/test.dart';

void main() {
  group('SkillRouter', () {
    late Directory tempDir;
    late ManifestReader reader;
    late SkillRouter router;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'flutter_skill_gen_router_test_',
      );
      reader = ManifestReader(projectPath: tempDir.path);
      router = SkillRouter(manifestReader: reader);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('routePrompt', () {
      test('returns empty result when no manifest', () {
        final result = router.routePrompt('add login screen');
        expect(result.selectedSkills, isEmpty);
        expect(result.matchedKeywords, isEmpty);
      });

      test('always includes always_inject entries', () {
        File(reader.manifestPath).writeAsStringSync('''
skills:
  - file: SKILL.md
    scope:
      - architecture
    always_inject: true
  - file: SKILL_auth.md
    scope:
      - login
''');

        final result = router.routePrompt('unrelated prompt');
        expect(result.selectedSkills, hasLength(1));
        expect(result.selectedSkills[0].file, 'SKILL.md');
      });

      test('matches keyword in prompt', () {
        File(reader.manifestPath).writeAsStringSync('''
skills:
  - file: SKILL.md
    scope: []
    always_inject: true
  - file: SKILL_auth.md
    scope:
      - login
      - authentication
''');

        final result = router.routePrompt('I need to fix the login screen');
        expect(result.selectedSkills, hasLength(2));
        expect(
          result.selectedSkills.map((e) => e.file),
          contains('SKILL_auth.md'),
        );
        expect(result.matchedKeywords, contains('login'));
      });

      test('matches case-insensitively', () {
        File(reader.manifestPath).writeAsStringSync('''
skills:
  - file: SKILL_auth.md
    scope:
      - Login
''');

        final result = router.routePrompt('fix the LOGIN page');
        expect(result.selectedSkills, hasLength(1));
      });

      test('records matched keywords', () {
        File(reader.manifestPath).writeAsStringSync('''
skills:
  - file: SKILL_auth.md
    scope:
      - authentication
      - login
  - file: SKILL_cart.md
    scope:
      - checkout
      - payment
''');

        final result = router.routePrompt(
          'add authentication and checkout flow',
        );
        expect(result.matchedKeywords, hasLength(2));
        expect(
          result.matchedKeywords,
          containsAll(['authentication', 'checkout']),
        );
      });

      test('does not duplicate skills on multiple keyword hits', () {
        File(reader.manifestPath).writeAsStringSync('''
skills:
  - file: SKILL_auth.md
    scope:
      - authentication
      - login
''');

        // Both keywords match, but the skill should appear once.
        final result = router.routePrompt('authentication and login screen');
        expect(result.selectedSkills, hasLength(1));
      });
    });

    group('routeFromFiles', () {
      test('returns empty result when no manifest', () {
        final result = router.routeFromFiles([
          'lib/features/auth/auth_screen.dart',
        ]);
        expect(result.selectedSkills, isEmpty);
      });

      test('detects domain from file paths and matches scope', () {
        File(reader.manifestPath).writeAsStringSync('''
skills:
  - file: SKILL.md
    scope: []
    always_inject: true
  - file: SKILL_auth.md
    scope:
      - auth
''');

        final result = router.routeFromFiles([
          'lib/features/auth/presentation/login_page.dart',
        ]);
        expect(
          result.selectedSkills.map((e) => e.file),
          contains('SKILL_auth.md'),
        );
        expect(result.matchedKeywords, contains('auth'));
      });
    });
  });

  group('DomainDetector', () {
    group('detectFromPaths', () {
      test('extracts feature names from features/ paths', () {
        final domains = DomainDetector.detectFromPaths([
          'lib/features/auth/presentation/login_page.dart',
          'lib/features/cart/data/cart_repository.dart',
        ]);
        expect(domains, containsAll(['auth', 'cart']));
      });

      test('extracts module names from modules/ paths', () {
        final domains = DomainDetector.detectFromPaths([
          'lib/modules/payments/payment_service.dart',
        ]);
        expect(domains, contains('payments'));
      });

      test('detects layer keywords', () {
        final domains = DomainDetector.detectFromPaths([
          'lib/data/repositories/user_repo.dart',
          'lib/presentation/widgets/button.dart',
        ]);
        expect(domains, containsAll(['data', 'presentation']));
      });

      test('combines features and layers', () {
        final domains = DomainDetector.detectFromPaths([
          'lib/features/auth/domain/entities/user.dart',
        ]);
        // Should detect 'auth' from features/ and 'domain' as layer.
        expect(domains, containsAll(['auth', 'domain']));
      });

      test('returns empty set for paths without signals', () {
        final domains = DomainDetector.detectFromPaths([
          'lib/main.dart',
          'lib/app.dart',
        ]);
        expect(domains, isEmpty);
      });

      test('deduplicates results', () {
        final domains = DomainDetector.detectFromPaths([
          'lib/features/auth/login.dart',
          'lib/features/auth/signup.dart',
        ]);
        expect(domains.where((d) => d == 'auth').length, 1);
      });
    });
  });
}
