import 'package:flutter_skill_gen/src/analyzers/domain_analyzer.dart';
import 'package:flutter_skill_gen/src/analyzers/structure_analyzer.dart';
import 'package:test/test.dart';

void main() {
  group('DomainAnalyzer', () {
    const projectPath = 'test/fixtures/sample_bloc_project';
    late DomainAnalyzer analyzer;

    setUp(() {
      analyzer = DomainAnalyzer(projectPath);
    });

    group('sample_bloc_project auth feature', () {
      test('returns featurePath relative to project root', () {
        final structure = StructureAnalyzer(projectPath).analyze();
        final facts = analyzer.analyze('auth', structure);
        expect(facts.featurePath, 'lib/features/auth');
      });

      test('detects BlocBuilder usage from login_page.dart', () {
        final structure = StructureAnalyzer(projectPath).analyze();
        final facts = analyzer.analyze('auth', structure);
        expect(facts.widgetUsageCounts['BlocBuilder'], greaterThanOrEqualTo(1));
      });

      test('emits zero counts for widgets not present', () {
        final structure = StructureAnalyzer(projectPath).analyze();
        final facts = analyzer.analyze('auth', structure);
        // Every tracked key must be in the map — consumers rely on
        // "absent" meaning zero, not missing.
        expect(facts.widgetUsageCounts.containsKey('ConsumerWidget'), isTrue);
        expect(facts.widgetUsageCounts['ConsumerWidget'], 0);
      });

      test('emits empty diFiles when DI is centralized outside feature', () {
        final structure = StructureAnalyzer(projectPath).analyze();
        final facts = analyzer.analyze('auth', structure);
        expect(facts.diFiles, isEmpty);
      });

      test('detects no wrapper classes in fixture without them', () {
        final structure = StructureAnalyzer(projectPath).analyze();
        final facts = analyzer.analyze('auth', structure);
        expect(facts.wrapperClasses, isEmpty);
      });
    });

    group('sample_bloc_project cart feature (presentation only)', () {
      test('detects only presentation layer', () {
        final structure = StructureAnalyzer(projectPath).analyze();
        final facts = analyzer.analyze('cart', structure);
        expect(facts.layers, ['presentation']);
      });
    });

    group('nonexistent domain', () {
      test('returns empty DomainFacts', () {
        final structure = StructureAnalyzer(projectPath).analyze();
        final facts = analyzer.analyze('does_not_exist', structure);
        expect(facts.featurePath, isNull);
        expect(facts.files, isEmpty);
        expect(facts.widgetUsageCounts, isEmpty);
        expect(facts.diFiles, isEmpty);
        expect(facts.wrapperClasses, isEmpty);
      });
    });
  });
}
