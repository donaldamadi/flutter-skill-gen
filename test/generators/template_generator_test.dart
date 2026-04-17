import 'package:flutter_skill_gen/src/generators/template_generator.dart';
import 'package:flutter_skill_gen/src/models/convention_info.dart';
import 'package:flutter_skill_gen/src/models/dependency_info.dart';
import 'package:flutter_skill_gen/src/models/pattern_info.dart';
import 'package:flutter_skill_gen/src/models/project_facts.dart';
import 'package:flutter_skill_gen/src/models/structure_info.dart';
import 'package:test/test.dart';

/// Helper to build a minimal [ProjectFacts] with overrides.
ProjectFacts _buildFacts({
  String projectName = 'test_app',
  String? projectDescription,
  String? dartSdk,
  String? flutterSdk,
  DependencyInfo dependencies = const DependencyInfo(),
  StructureInfo structure = const StructureInfo(organization: 'feature-first'),
  PatternInfo patterns = const PatternInfo(),
  ConventionInfo conventions = const ConventionInfo(),
  TestingInfo? testing,
  ComplexityInfo? complexity,
}) {
  return ProjectFacts(
    projectName: projectName,
    projectDescription: projectDescription,
    dartSdk: dartSdk,
    flutterSdk: flutterSdk,
    dependencies: dependencies,
    structure: structure,
    patterns: patterns,
    conventions: conventions,
    testing: testing,
    complexity: complexity,
    generatedAt: '2026-04-16T12:00:00Z',
    toolVersion: '0.1.0',
  );
}

void main() {
  group('TemplateGenerator', () {
    group('header', () {
      test('includes project name as H1', () {
        final md = TemplateGenerator.generate(
          _buildFacts(projectName: 'my_cool_app'),
        );
        expect(md, startsWith('# my_cool_app'));
      });

      test('includes project description when present', () {
        final md = TemplateGenerator.generate(
          _buildFacts(projectDescription: 'An amazing app'),
        );
        expect(md, contains('An amazing app'));
      });

      test('includes tech stack summary', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            patterns: const PatternInfo(
              architecture: 'clean_architecture',
              stateManagement: 'bloc',
              routing: 'go_router',
            ),
          ),
        );
        expect(md, contains('**Tech stack:**'));
        expect(md, contains('Clean Architecture'));
        expect(md, contains('Bloc'));
        expect(md, contains('Go Router'));
      });

      test('includes SDK constraints', () {
        final md = TemplateGenerator.generate(
          _buildFacts(dartSdk: '^3.5.0', flutterSdk: '>=3.24.0'),
        );
        expect(md, contains('**Dart SDK:** `^3.5.0`'));
        expect(md, contains('**Flutter SDK:** `>=3.24.0`'));
      });
    });

    group('architecture section', () {
      test('includes architecture heading', () {
        final md = TemplateGenerator.generate(_buildFacts());
        expect(md, contains('## Architecture'));
      });

      test('describes architecture pattern', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            patterns: const PatternInfo(architecture: 'clean_architecture'),
          ),
        );
        expect(md, contains('**Clean Architecture**'));
      });

      test('lists top-level directories', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            structure: const StructureInfo(
              organization: 'feature-first',
              topLevelDirs: ['core', 'features', 'shared'],
            ),
          ),
        );
        expect(md, contains('`core`'));
        expect(md, contains('`features`'));
        expect(md, contains('`shared`'));
      });

      test('lists feature directories', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            structure: const StructureInfo(
              organization: 'feature-first',
              featureDirs: ['auth', 'home', 'cart'],
            ),
          ),
        );
        expect(md, contains('Features:'));
        expect(md, contains('`auth`'));
        expect(md, contains('`home`'));
        expect(md, contains('`cart`'));
      });

      test('describes layer pattern', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            structure: const StructureInfo(
              organization: 'feature-first',
              layerPattern: LayerPattern(
                detected: 'clean_architecture',
                layers: ['data', 'domain', 'presentation'],
                perFeature: true,
              ),
            ),
          ),
        );
        expect(md, contains('`data`'));
        expect(md, contains('`domain`'));
        expect(md, contains('`presentation`'));
        expect(md, contains('feature'));
      });

      test('notes monorepo when detected', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            structure: const StructureInfo(
              organization: 'feature-first',
              hasSeparatePackages: true,
            ),
          ),
        );
        expect(md, contains('**monorepo**'));
      });
    });

    group('state management section', () {
      test('omitted when no state management detected', () {
        final md = TemplateGenerator.generate(_buildFacts());
        expect(md, isNot(contains('## State Management')));
      });

      test('included when state management detected', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            patterns: const PatternInfo(stateManagement: 'bloc'),
            dependencies: const DependencyInfo(
              stateManagement: ['flutter_bloc', 'bloc'],
            ),
          ),
        );
        expect(md, contains('## State Management'));
        expect(md, contains('**Bloc**'));
        expect(md, contains('`flutter_bloc`'));
        expect(md, contains('`bloc`'));
      });

      test('includes BLoC naming conventions', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            patterns: const PatternInfo(stateManagement: 'bloc'),
            conventions: const ConventionInfo(
              naming: NamingConvention(
                blocEvents: 'PascalCaseEvent',
                blocStates: 'PascalCaseState',
              ),
            ),
          ),
        );
        expect(md, contains('BLoC events:'));
        expect(md, contains('BLoC states:'));
      });
    });

    group('routing section', () {
      test('omitted when no routing detected', () {
        final md = TemplateGenerator.generate(_buildFacts());
        expect(md, isNot(contains('## Routing')));
      });

      test('included when routing detected', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            patterns: const PatternInfo(routing: 'go_router'),
            dependencies: const DependencyInfo(routing: ['go_router']),
          ),
        );
        expect(md, contains('## Routing'));
        expect(md, contains('**Go Router**'));
      });
    });

    group('dependency injection section', () {
      test('omitted when no DI detected', () {
        final md = TemplateGenerator.generate(_buildFacts());
        expect(md, isNot(contains('## Dependency Injection')));
      });

      test('included when DI detected', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            patterns: const PatternInfo(di: 'get_it_injectable'),
            dependencies: const DependencyInfo(di: ['get_it', 'injectable']),
          ),
        );
        expect(md, contains('## Dependency Injection'));
        expect(md, contains('**Get It Injectable**'));
      });
    });

    group('data layer section', () {
      test('omitted when no data layer info', () {
        final md = TemplateGenerator.generate(_buildFacts());
        expect(md, isNot(contains('## Data Layer')));
      });

      test('includes API client info', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            patterns: const PatternInfo(apiClient: 'dio_retrofit'),
            dependencies: const DependencyInfo(networking: ['dio', 'retrofit']),
          ),
        );
        expect(md, contains('## Data Layer'));
        expect(md, contains('**Dio Retrofit**'));
        expect(md, contains('`dio`'));
      });

      test('includes local storage info', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            dependencies: const DependencyInfo(
              localStorage: ['hive', 'hive_flutter'],
            ),
          ),
        );
        expect(md, contains('Local storage:'));
        expect(md, contains('`hive`'));
      });

      test('includes error handling info', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            patterns: const PatternInfo(errorHandling: 'either_dartz'),
          ),
        );
        expect(md, contains('Error handling:'));
        expect(md, contains('**Either Dartz**'));
      });

      test('includes model serialization info', () {
        final md = TemplateGenerator.generate(
          _buildFacts(patterns: const PatternInfo(modelApproach: 'freezed')),
        );
        expect(md, contains('Model serialization:'));
        expect(md, contains('**Freezed**'));
      });
    });

    group('conventions section', () {
      test('omitted when no conventions detected', () {
        final md = TemplateGenerator.generate(_buildFacts());
        expect(md, isNot(contains('## Code Conventions')));
      });

      test('includes naming conventions', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            conventions: const ConventionInfo(
              naming: NamingConvention(
                files: 'snake_case',
                classes: 'PascalCase',
              ),
            ),
          ),
        );
        expect(md, contains('## Code Conventions'));
        expect(md, contains('File naming: **snake_case**'));
        expect(md, contains('Class naming: **PascalCase**'));
      });

      test('includes import conventions', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            conventions: const ConventionInfo(
              imports: ImportConvention(style: 'relative', barrelFiles: true),
            ),
          ),
        );
        expect(md, contains('Import style: **relative**'));
        expect(md, contains('Barrel files: **yes**'));
      });

      test('includes code samples', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            conventions: const ConventionInfo(
              samples: [
                CodeSample(
                  type: 'bloc_example',
                  file: 'lib/features/auth/bloc.dart',
                  snippet: 'class AuthBloc extends Bloc {}',
                ),
              ],
            ),
          ),
        );
        expect(md, contains('### Bloc Example'));
        expect(md, contains('```dart'));
        expect(md, contains('class AuthBloc extends Bloc {}'));
      });
    });

    group('rules section', () {
      test('omitted when no rules derived', () {
        final md = TemplateGenerator.generate(
          _buildFacts(structure: const StructureInfo(organization: 'flat')),
        );
        expect(md, isNot(contains("## Do / Don't Rules")));
      });

      test('derives clean architecture rule', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            patterns: const PatternInfo(architecture: 'clean_architecture'),
          ),
        );
        expect(md, contains('Clean Architecture layer boundaries'));
      });

      test('derives BLoC rules', () {
        final md = TemplateGenerator.generate(
          _buildFacts(patterns: const PatternInfo(stateManagement: 'bloc')),
        );
        expect(md, contains('BLoC/Cubit'));
        expect(md, contains('`Event`'));
        expect(md, contains('`State`'));
      });

      test('derives Riverpod rule', () {
        final md = TemplateGenerator.generate(
          _buildFacts(patterns: const PatternInfo(stateManagement: 'riverpod')),
        );
        expect(md, contains('Riverpod providers'));
      });

      test('derives freezed rule', () {
        final md = TemplateGenerator.generate(
          _buildFacts(patterns: const PatternInfo(modelApproach: 'freezed')),
        );
        expect(md, contains('`freezed`'));
        expect(md, contains('`build_runner`'));
      });

      test('derives either error handling rule', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            patterns: const PatternInfo(errorHandling: 'either_dartz'),
          ),
        );
        expect(md, contains('`Either`'));
      });

      test('derives relative import rule', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            conventions: const ConventionInfo(
              imports: ImportConvention(style: 'relative'),
            ),
          ),
        );
        expect(md, contains('relative imports'));
      });

      test('derives package import rule', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            conventions: const ConventionInfo(
              imports: ImportConvention(style: 'package'),
            ),
          ),
        );
        expect(md, contains('package imports'));
      });

      test('derives feature-first organization rule', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            structure: const StructureInfo(organization: 'feature-first'),
          ),
        );
        expect(md, contains('`features/<name>/`'));
      });

      test('derives injectable rule', () {
        final md = TemplateGenerator.generate(
          _buildFacts(patterns: const PatternInfo(di: 'get_it_injectable')),
        );
        expect(md, contains('`@injectable`'));
        expect(md, contains('`@singleton`'));
      });
    });

    group('testing section', () {
      test('omitted when no testing info', () {
        final md = TemplateGenerator.generate(_buildFacts());
        expect(md, isNot(contains('## Testing')));
      });

      test('lists test types', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            testing: const TestingInfo(
              hasUnitTests: true,
              hasWidgetTests: true,
            ),
          ),
        );
        expect(md, contains('## Testing'));
        expect(md, contains('unit'));
        expect(md, contains('widget'));
      });

      test('includes mocking library', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            testing: const TestingInfo(
              hasUnitTests: true,
              mockingLibrary: 'mocktail',
            ),
          ),
        );
        expect(md, contains('**mocktail**'));
      });

      test('includes test structure', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            testing: const TestingInfo(
              hasUnitTests: true,
              testStructure: 'mirrors_lib',
            ),
          ),
        );
        expect(md, contains('**mirrors_lib**'));
      });
    });

    group('code generation section', () {
      test('omitted when no code gen deps', () {
        final md = TemplateGenerator.generate(_buildFacts());
        expect(md, isNot(contains('## Code Generation')));
      });

      test('included with build_runner command', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            dependencies: const DependencyInfo(
              codeGeneration: ['build_runner', 'json_serializable'],
            ),
          ),
        );
        expect(md, contains('## Code Generation'));
        expect(
          md,
          contains(
            'dart run build_runner build '
            '--delete-conflicting-outputs',
          ),
        );
      });

      test('includes freezed-specific note', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            dependencies: const DependencyInfo(
              codeGeneration: ['freezed', 'build_runner'],
            ),
          ),
        );
        expect(md, contains('@freezed'));
        expect(md, contains('@JsonSerializable'));
      });
    });

    group('full BLoC project output', () {
      test('generates complete markdown for BLoC project', () {
        final md = TemplateGenerator.generate(
          _buildFacts(
            projectName: 'sample_bloc_app',
            projectDescription: 'A sample app with Clean Architecture and BLoC',
            dartSdk: '^3.5.0',
            flutterSdk: '>=3.24.0',
            dependencies: const DependencyInfo(
              stateManagement: ['flutter_bloc', 'bloc'],
              routing: ['go_router'],
              di: ['get_it', 'injectable'],
              networking: ['dio', 'retrofit'],
              localStorage: ['hive', 'hive_flutter'],
              codeGeneration: ['freezed', 'build_runner'],
              testing: ['bloc_test', 'mocktail'],
            ),
            structure: const StructureInfo(
              organization: 'feature-first',
              topLevelDirs: ['core', 'features'],
              featureDirs: ['auth', 'home', 'cart'],
              layerPattern: LayerPattern(
                detected: 'clean_architecture',
                layers: ['data', 'domain', 'presentation'],
                perFeature: true,
              ),
            ),
            patterns: const PatternInfo(
              architecture: 'clean_architecture',
              stateManagement: 'bloc',
              routing: 'go_router',
              di: 'get_it_injectable',
              apiClient: 'dio_retrofit',
              errorHandling: 'either_dartz',
              modelApproach: 'freezed',
            ),
            conventions: const ConventionInfo(
              naming: NamingConvention(
                files: 'snake_case',
                classes: 'PascalCase',
              ),
              imports: ImportConvention(style: 'relative', barrelFiles: false),
            ),
            testing: const TestingInfo(
              hasUnitTests: true,
              mockingLibrary: 'mocktail',
              testStructure: 'mirrors_lib',
            ),
          ),
        );

        // Verify all sections present.
        expect(md, contains('# sample_bloc_app'));
        expect(md, contains('## Architecture'));
        expect(md, contains('## State Management'));
        expect(md, contains('## Routing'));
        expect(md, contains('## Dependency Injection'));
        expect(md, contains('## Data Layer'));
        expect(md, contains('## Code Conventions'));
        expect(md, contains("## Do / Don't Rules"));
        expect(md, contains('## Testing'));
        expect(md, contains('## Code Generation'));
      });
    });
  });
}
