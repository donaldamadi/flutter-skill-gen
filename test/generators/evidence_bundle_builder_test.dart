import 'package:flutter_skill_gen/src/analyzers/structure_analyzer.dart';
import 'package:flutter_skill_gen/src/generators/evidence_bundle_builder.dart';
import 'package:flutter_skill_gen/src/models/domain_facts.dart';
import 'package:test/test.dart';

void main() {
  group('EvidenceBundleBuilder', () {
    const builder = EvidenceBundleBuilder();

    group('features', () {
      test('constructs FeatureEvidence from DomainFacts + breakdown', () {
        final bundle = builder.build(
          projectName: 'demo',
          domainFacts: const [
            DomainFacts(
              domainName: 'auth',
              featurePath: 'lib/features/auth',
              files: ['lib/features/auth/presentation/login_page.dart'],
              layers: ['presentation'],
              stateClasses: ['AuthBloc'],
              entities: ['User'],
              widgetUsageCounts: {'BlocBuilder': 3, 'ConsumerWidget': 0},
              wrapperClasses: ['AuthWrapper'],
              diFiles: [],
            ),
          ],
          featureBreakdown: const {
            'auth': FeatureLayerInfo(
              relativePath: 'lib/features/auth',
              layersPresent: ['data', 'domain', 'presentation'],
            ),
          },
          allFilePaths: const [
            'lib/features/auth/presentation/login_page.dart',
          ],
          allClassNames: const ['AuthBloc', 'User', 'AuthWrapper'],
        );

        expect(bundle.features, hasLength(1));
        final auth = bundle.features.single;
        expect(auth.name, 'auth');
        expect(auth.path, 'lib/features/auth');
        expect(
          auth.layersPresent,
          containsAll(['data', 'domain', 'presentation']),
        );
        expect(auth.layersAbsent, isEmpty);
        expect(auth.widgetUsage['BlocBuilder'], 3);
        expect(auth.widgetUsage['ConsumerWidget'], 0);
        expect(auth.stateClasses.single.name, 'AuthBloc');
        expect(auth.entityClasses.single.name, 'User');
        expect(auth.wrapperClasses.single.name, 'AuthWrapper');
      });

      test('layersAbsent reports canonical layers that are missing', () {
        final bundle = builder.build(
          projectName: 'demo',
          domainFacts: const [
            DomainFacts(
              domainName: 'cart',
              featurePath: 'lib/features/cart',
              layers: ['presentation'],
            ),
          ],
          featureBreakdown: const {
            'cart': FeatureLayerInfo(
              relativePath: 'lib/features/cart',
              layersPresent: ['presentation'],
            ),
          },
          allFilePaths: const [],
          allClassNames: const [],
        );

        final cart = bundle.features.single;
        expect(cart.layersPresent, ['presentation']);
        expect(cart.layersAbsent, containsAll(['data', 'domain']));
        expect(cart.layersAbsent, isNot(contains('presentation')));
      });

      test('falls back to DomainFacts.layers when breakdown missing', () {
        final bundle = builder.build(
          projectName: 'demo',
          domainFacts: const [
            DomainFacts(
              domainName: 'orphan',
              featurePath: 'lib/features/orphan',
              layers: ['presentation'],
            ),
          ],
          featureBreakdown: const {},
          allFilePaths: const [],
          allClassNames: const [],
        );

        expect(bundle.features.single.layersPresent, ['presentation']);
      });
    });

    group('class -> file pairing', () {
      test('pairs CamelCase class with snake_case file when present', () {
        final bundle = builder.build(
          projectName: 'demo',
          domainFacts: const [
            DomainFacts(
              domainName: 'auth',
              featurePath: 'lib/features/auth',
              files: [
                'lib/features/auth/presentation/bloc/auth_bloc.dart',
                'lib/features/auth/domain/entities/user.dart',
              ],
              stateClasses: ['AuthBloc'],
              entities: ['User'],
            ),
          ],
          featureBreakdown: const {},
          allFilePaths: const [],
          allClassNames: const ['AuthBloc', 'User'],
        );

        final feature = bundle.features.single;
        expect(
          feature.stateClasses.single.file,
          'lib/features/auth/presentation/bloc/auth_bloc.dart',
        );
        expect(
          feature.entityClasses.single.file,
          'lib/features/auth/domain/entities/user.dart',
        );
      });

      test('returns empty file string when no snake_case match', () {
        final bundle = builder.build(
          projectName: 'demo',
          domainFacts: const [
            DomainFacts(
              domainName: 'auth',
              files: ['lib/features/auth/random_name.dart'],
              stateClasses: ['AuthBloc'],
            ),
          ],
          featureBreakdown: const {},
          allFilePaths: const [],
          allClassNames: const ['AuthBloc'],
        );

        expect(bundle.features.single.stateClasses.single.file, isEmpty);
      });
    });

    group('DI evidence', () {
      test('perFeature=true when every feature has at least one diFile', () {
        final bundle = builder.build(
          projectName: 'demo',
          domainFacts: const [
            DomainFacts(
              domainName: 'auth',
              diFiles: ['lib/features/auth/auth_injection.dart'],
            ),
            DomainFacts(
              domainName: 'home',
              diFiles: ['lib/features/home/home_injection.dart'],
            ),
          ],
          featureBreakdown: const {},
          allFilePaths: const [
            'lib/features/auth/auth_injection.dart',
            'lib/features/home/home_injection.dart',
          ],
          allClassNames: const [],
          diStyle: 'get_it_injectable',
        );

        expect(bundle.di.perFeature, isTrue);
        expect(bundle.di.style, 'get_it_injectable');
        expect(
          bundle.di.registrationFiles,
          containsAll([
            'lib/features/auth/auth_injection.dart',
            'lib/features/home/home_injection.dart',
          ]),
        );
      });

      test('perFeature=false when any feature lacks a diFile', () {
        final bundle = builder.build(
          projectName: 'demo',
          domainFacts: const [
            DomainFacts(
              domainName: 'auth',
              diFiles: ['lib/features/auth/auth_injection.dart'],
            ),
            DomainFacts(domainName: 'cart'),
          ],
          featureBreakdown: const {},
          allFilePaths: const ['lib/features/auth/auth_injection.dart'],
          allClassNames: const [],
        );

        expect(bundle.di.perFeature, isFalse);
      });

      test('perFeature=false when there are no features', () {
        final bundle = builder.build(
          projectName: 'demo',
          domainFacts: const [],
          featureBreakdown: const {},
          allFilePaths: const [],
          allClassNames: const [],
        );

        expect(bundle.di.perFeature, isFalse);
      });

      test('detects central DI files by known filename', () {
        final bundle = builder.build(
          projectName: 'demo',
          domainFacts: const [DomainFacts(domainName: 'auth')],
          featureBreakdown: const {},
          allFilePaths: const [
            'lib/core/di/injection_container.dart',
            'lib/features/auth/presentation/login.dart',
          ],
          allClassNames: const [],
        );

        expect(
          bundle.di.registrationFiles,
          contains('lib/core/di/injection_container.dart'),
        );
        expect(bundle.di.perFeature, isFalse);
      });

      test('detects central DI files by *_module.dart suffix', () {
        final bundle = builder.build(
          projectName: 'demo',
          domainFacts: const [],
          featureBreakdown: const {},
          allFilePaths: const [
            'lib/core/api_module.dart',
            'lib/core/unrelated.dart',
          ],
          allClassNames: const [],
        );

        expect(
          bundle.di.registrationFiles,
          contains('lib/core/api_module.dart'),
        );
        expect(
          bundle.di.registrationFiles,
          isNot(contains('lib/core/unrelated.dart')),
        );
      });
    });

    group('widget usage aggregation', () {
      test('sums per-feature widget counts into globalWidgetUsage', () {
        final bundle = builder.build(
          projectName: 'demo',
          domainFacts: const [
            DomainFacts(
              domainName: 'auth',
              widgetUsageCounts: {'BlocBuilder': 3, 'BlocListener': 1},
            ),
            DomainFacts(
              domainName: 'home',
              widgetUsageCounts: {'BlocBuilder': 2, 'ConsumerWidget': 5},
            ),
          ],
          featureBreakdown: const {},
          allFilePaths: const [],
          allClassNames: const [],
        );

        expect(bundle.globalWidgetUsage['BlocBuilder'], 5);
        expect(bundle.globalWidgetUsage['BlocListener'], 1);
        expect(bundle.globalWidgetUsage['ConsumerWidget'], 5);
      });
    });

    group('known file patterns', () {
      test('emits only patterns that actually match a file', () {
        final bundle = builder.build(
          projectName: 'demo',
          domainFacts: const [],
          featureBreakdown: const {},
          allFilePaths: const [
            'lib/features/auth/auth_bloc.dart',
            'lib/features/auth/auth_state.dart',
            'lib/features/auth/login_page.dart',
            'lib/shared/user.dart',
          ],
          allClassNames: const [],
        );

        expect(bundle.knownFilePatterns, contains('*_bloc.dart'));
        expect(bundle.knownFilePatterns, contains('*_state.dart'));
        expect(bundle.knownFilePatterns, contains('*_page.dart'));
        expect(bundle.knownFilePatterns, isNot(contains('*_cubit.dart')));
        expect(bundle.knownFilePatterns, isNot(contains('*_notifier.dart')));
      });
    });

    group('file manifest', () {
      test('pass-through of allFilePaths and allClassNames', () {
        final bundle = builder.build(
          projectName: 'demo',
          domainFacts: const [],
          featureBreakdown: const {},
          allFilePaths: const ['lib/a.dart', 'lib/b.dart'],
          allClassNames: const ['A', 'B'],
        );

        expect(bundle.fileManifest.allFilePaths, ['lib/a.dart', 'lib/b.dart']);
        expect(bundle.fileManifest.allClassNames, ['A', 'B']);
      });
    });
  });
}
