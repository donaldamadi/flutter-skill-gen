import 'dart:io';

import 'package:flutter_skill_gen/src/templates/template_scaffolder.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'flutter_skill_gen_scaffold_test_',
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('TemplateId', () {
    test('contains clean_bloc', () {
      expect(TemplateId.all, contains('clean_bloc'));
    });

    test('contains clean_riverpod', () {
      expect(TemplateId.all, contains('clean_riverpod'));
    });

    test('has exactly 2 templates', () {
      expect(TemplateId.all, hasLength(2));
    });
  });

  group('TemplateScaffolder', () {
    group('clean_bloc template', () {
      test('scaffolds successfully', () {
        final outputPath = '${tempDir.path}/bloc_app';
        final scaffolder = TemplateScaffolder(
          templateId: TemplateId.cleanBloc,
          projectName: 'bloc_app',
          outputPath: outputPath,
        );

        expect(scaffolder.scaffold(), isTrue);
      });

      test('creates pubspec.yaml with project name', () {
        final outputPath = '${tempDir.path}/bloc_app';
        TemplateScaffolder(
          templateId: TemplateId.cleanBloc,
          projectName: 'my_bloc_app',
          outputPath: outputPath,
        ).scaffold();

        final pubspec = File('$outputPath/pubspec.yaml');
        expect(pubspec.existsSync(), isTrue);
        final content = pubspec.readAsStringSync();
        expect(content, contains('name: my_bloc_app'));
      });

      test('creates main.dart', () {
        final outputPath = '${tempDir.path}/bloc_app';
        TemplateScaffolder(
          templateId: TemplateId.cleanBloc,
          projectName: 'bloc_app',
          outputPath: outputPath,
        ).scaffold();

        expect(File('$outputPath/lib/main.dart').existsSync(), isTrue);
      });

      test('creates Clean Architecture structure', () {
        final outputPath = '${tempDir.path}/bloc_app';
        TemplateScaffolder(
          templateId: TemplateId.cleanBloc,
          projectName: 'bloc_app',
          outputPath: outputPath,
        ).scaffold();

        expect(Directory('$outputPath/lib/core').existsSync(), isTrue);
        expect(Directory('$outputPath/lib/features/home').existsSync(), isTrue);
        expect(
          Directory('$outputPath/lib/features/home/domain').existsSync(),
          isTrue,
        );
        expect(
          Directory('$outputPath/lib/features/home/data').existsSync(),
          isTrue,
        );
        expect(
          Directory('$outputPath/lib/features/home/presentation').existsSync(),
          isTrue,
        );
      });

      test('creates BLoC files', () {
        final outputPath = '${tempDir.path}/bloc_app';
        TemplateScaffolder(
          templateId: TemplateId.cleanBloc,
          projectName: 'bloc_app',
          outputPath: outputPath,
        ).scaffold();

        final blocDir = '$outputPath/lib/features/home/presentation/bloc';
        expect(File('$blocDir/home_bloc.dart').existsSync(), isTrue);
        expect(File('$blocDir/home_event.dart').existsSync(), isTrue);
        expect(File('$blocDir/home_state.dart').existsSync(), isTrue);
      });

      test('creates DI setup', () {
        final outputPath = '${tempDir.path}/bloc_app';
        TemplateScaffolder(
          templateId: TemplateId.cleanBloc,
          projectName: 'bloc_app',
          outputPath: outputPath,
        ).scaffold();

        expect(
          File('$outputPath/lib/core/di/injection.dart').existsSync(),
          isTrue,
        );
      });

      test('creates test directory', () {
        final outputPath = '${tempDir.path}/bloc_app';
        TemplateScaffolder(
          templateId: TemplateId.cleanBloc,
          projectName: 'bloc_app',
          outputPath: outputPath,
        ).scaffold();

        expect(Directory('$outputPath/test').existsSync(), isTrue);
      });

      test('creates .skillrc.yaml', () {
        final outputPath = '${tempDir.path}/bloc_app';
        TemplateScaffolder(
          templateId: TemplateId.cleanBloc,
          projectName: 'bloc_app',
          outputPath: outputPath,
        ).scaffold();

        expect(File('$outputPath/.skillrc.yaml').existsSync(), isTrue);
      });

      test('includes BLoC dependencies in pubspec', () {
        final outputPath = '${tempDir.path}/bloc_app';
        TemplateScaffolder(
          templateId: TemplateId.cleanBloc,
          projectName: 'bloc_app',
          outputPath: outputPath,
        ).scaffold();

        final content = File('$outputPath/pubspec.yaml').readAsStringSync();
        expect(content, contains('flutter_bloc:'));
        expect(content, contains('bloc:'));
        expect(content, contains('get_it:'));
        expect(content, contains('go_router:'));
        expect(content, contains('dartz:'));
        expect(content, contains('freezed_annotation:'));
      });
    });

    group('clean_riverpod template', () {
      test('scaffolds successfully', () {
        final outputPath = '${tempDir.path}/riverpod_app';
        final scaffolder = TemplateScaffolder(
          templateId: TemplateId.cleanRiverpod,
          projectName: 'riverpod_app',
          outputPath: outputPath,
        );

        expect(scaffolder.scaffold(), isTrue);
      });

      test('creates pubspec.yaml with Riverpod deps', () {
        final outputPath = '${tempDir.path}/riverpod_app';
        TemplateScaffolder(
          templateId: TemplateId.cleanRiverpod,
          projectName: 'riverpod_app',
          outputPath: outputPath,
        ).scaffold();

        final content = File('$outputPath/pubspec.yaml').readAsStringSync();
        expect(content, contains('flutter_riverpod:'));
        expect(content, contains('riverpod_annotation:'));
        expect(content, contains('auto_route:'));
        expect(content, contains('fpdart:'));
      });

      test('creates provider files instead of BLoC', () {
        final outputPath = '${tempDir.path}/riverpod_app';
        TemplateScaffolder(
          templateId: TemplateId.cleanRiverpod,
          projectName: 'riverpod_app',
          outputPath: outputPath,
        ).scaffold();

        expect(
          File(
            '$outputPath/lib/features/home/presentation/'
            'providers/home_providers.dart',
          ).existsSync(),
          isTrue,
        );
      });

      test('uses ProviderScope in main.dart', () {
        final outputPath = '${tempDir.path}/riverpod_app';
        TemplateScaffolder(
          templateId: TemplateId.cleanRiverpod,
          projectName: 'riverpod_app',
          outputPath: outputPath,
        ).scaffold();

        final content = File('$outputPath/lib/main.dart').readAsStringSync();
        expect(content, contains('ProviderScope'));
      });

      test('uses fpdart Either in failures', () {
        final outputPath = '${tempDir.path}/riverpod_app';
        TemplateScaffolder(
          templateId: TemplateId.cleanRiverpod,
          projectName: 'riverpod_app',
          outputPath: outputPath,
        ).scaffold();

        final content = File(
          '$outputPath/lib/core/error/failures.dart',
        ).readAsStringSync();
        expect(content, contains('fpdart'));
        expect(content, contains('Either'));
      });
    });

    group('error handling', () {
      test('fails for unknown template', () {
        final scaffolder = TemplateScaffolder(
          templateId: 'unknown_template',
          projectName: 'test',
          outputPath: '${tempDir.path}/test',
        );

        expect(scaffolder.scaffold(), isFalse);
      });

      test('fails if output directory is not empty', () {
        final outputPath = '${tempDir.path}/nonempty';
        Directory(outputPath).createSync();
        File('$outputPath/existing.txt').writeAsStringSync('data');

        final scaffolder = TemplateScaffolder(
          templateId: TemplateId.cleanBloc,
          projectName: 'test',
          outputPath: outputPath,
        );

        expect(scaffolder.scaffold(), isFalse);
      });

      test('replaces __PROJECT_NAME__ in all files', () {
        final outputPath = '${tempDir.path}/my_project';
        TemplateScaffolder(
          templateId: TemplateId.cleanBloc,
          projectName: 'my_project',
          outputPath: outputPath,
        ).scaffold();

        final mainContent = File(
          '$outputPath/lib/main.dart',
        ).readAsStringSync();
        expect(mainContent, isNot(contains('__PROJECT_NAME__')));
        expect(mainContent, contains('my_project'));
      });
    });
  });
}
