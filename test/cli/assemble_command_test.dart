import 'dart:io';

import 'package:flutter_skill_gen/src/cli/cli_runner.dart';
import 'package:flutter_skill_gen/src/skill/skill_workspace.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'skill_workspace_fixture.dart';

/// A draft that only makes claims the evidence bundle supports, so it
/// survives verification unchanged.
const _groundedDraft = '''
## Project Overview

A shopping app. Features are organised feature-first under lib/.

## Architecture

Each feature's presentation layer holds its widgets and state.

## Do / Don't Rules

- DO keep feature code inside its own directory.
- DON'T use relative imports across features.
''';

void main() {
  group('AssembleCommand', () {
    late Directory temp;
    late String projectPath;
    late SkillWorkspace workspace;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('flutter_skill_gen_assemble_');
      projectPath = copyFixture('sample_bloc_project', temp.path);
      workspace = SkillWorkspace(
        directory: p.join(projectPath, SkillWorkspace.defaultDirName),
      );
    });

    tearDown(() => temp.deleteSync(recursive: true));

    Future<void> runPrompt({bool split = false}) async {
      final code = await CliRunner().run([
        'prompt',
        '--path',
        projectPath,
        if (split) '--split',
      ]);
      expect(code, 0);
    }

    void writeDrafts({String content = _groundedDraft}) {
      for (final scope in workspace.readPlan().scopes) {
        File(workspace.draftPath(scope))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(content);
      }
    }

    test('command is registered', () {
      expect(CliRunner().commands.keys, contains('assemble'));
    });

    test('fails cleanly with no workspace', () async {
      final code = await CliRunner().run(['assemble', '--path', projectPath]);
      expect(code, 66);
    });

    test('fails when a draft is missing', () async {
      await runPrompt();
      final code = await CliRunner().run(['assemble', '--path', projectPath]);
      expect(code, 65);
    });

    test('treats an empty draft as missing', () async {
      await runPrompt();
      writeDrafts(content: '   \n  ');

      final code = await CliRunner().run(['assemble', '--path', projectPath]);
      expect(code, 65);
    });

    test('completes the round trip without any API key', () async {
      // prompt -> an external author writes drafts -> assemble.
      // No provider is configured anywhere in this flow.
      await runPrompt();
      writeDrafts();

      final code = await CliRunner().run(['assemble', '--path', projectPath]);
      expect(code, 0);

      final skill = File(p.join(projectPath, 'SKILL.md'));
      expect(skill.existsSync(), isTrue);
      expect(skill.readAsStringSync(), contains('Project Overview'));
    });

    test('adds frontmatter the draft did not carry', () async {
      await runPrompt();
      writeDrafts();
      await CliRunner().run(['assemble', '--path', projectPath]);

      final content = File(p.join(projectPath, 'SKILL.md')).readAsStringSync();

      expect(content, startsWith('---\n'));
      expect(content, contains('name:'));
      expect(content, contains('description:'));
      expect(_groundedDraft, isNot(contains('---')));
    });

    test('splices in the generated gotchas and diagram', () async {
      // These come from trusted generators, never from the author, so
      // an agent-written draft gets them just like an API draft does.
      await runPrompt();
      writeDrafts();
      await CliRunner().run(['assemble', '--path', projectPath]);

      final content = File(p.join(projectPath, 'SKILL.md')).readAsStringSync();

      expect(content.length, greaterThan(_groundedDraft.length));
      expect(
        content.toLowerCase(),
        anyOf(contains('gotcha'), contains('data flow')),
      );
    });

    test('writes the facts and manifest at the project root', () async {
      await runPrompt();
      writeDrafts();
      await CliRunner().run(['assemble', '--path', projectPath]);

      expect(
        File(p.join(projectPath, '.skill_facts.json')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(projectPath, '.skill_manifest.yaml')).existsSync(),
        isTrue,
      );
    });

    test('annotates a claim the evidence does not support', () async {
      await runPrompt();
      writeDrafts(
        content:
            '## Architecture\n\n'
            'State lives in `lib/features/auth/presentation/'
            'totally_invented_file.dart`.\n',
      );

      final code = await CliRunner().run(['assemble', '--path', projectPath]);
      expect(code, 0);

      final content = File(p.join(projectPath, 'SKILL.md')).readAsStringSync();
      expect(content, contains('UNVERIFIED'));
    });

    test('does not fail the run in the default verifier mode', () async {
      // Fatal mode is driven by FLUTTER_SKILL_VERIFIER_MODE, which the
      // generator reads directly; that path is asserted in
      // skill_generator_assemble_test.dart. Here: the default mode
      // annotates rather than aborting, so the author still gets a
      // file to fix.
      await runPrompt();
      writeDrafts(
        content:
            '## Architecture\n\n'
            'See `lib/features/auth/presentation/'
            'totally_invented_file.dart`.\n',
      );

      final code = await CliRunner().run(['assemble', '--path', projectPath]);
      expect(code, 0);
    });

    test('assembles every scope in split mode', () async {
      await runPrompt(split: true);
      writeDrafts();

      final code = await CliRunner().run(['assemble', '--path', projectPath]);
      expect(code, 0);

      final scopes = workspace.readPlan().scopes;
      expect(scopes.length, greaterThan(1));
      for (final scope in scopes.where((s) => s != 'core')) {
        expect(
          File(p.join(projectPath, 'SKILL_$scope.md')).existsSync(),
          isTrue,
          reason: 'missing SKILL_$scope.md',
        );
      }
    });

    test('non-split naming matches what analyze produces', () async {
      // Same project, two routes to a single SKILL.md: the frontmatter
      // identity must not depend on which command wrote it, or a
      // switch between them silently renames the skill.
      await CliRunner().run(['prompt', '--path', projectPath, '--no-split']);
      writeDrafts();
      await CliRunner().run(['assemble', '--path', projectPath]);

      final assembled = File(
        p.join(projectPath, 'SKILL.md'),
      ).readAsStringSync().split('\n').firstWhere((l) => l.startsWith('name:'));

      expect(assembled, 'name: sample-bloc-app');
      expect(assembled, isNot(contains('-core')));
    });

    test('--clean removes the workspace', () async {
      await runPrompt();
      writeDrafts();

      final code = await CliRunner().run([
        'assemble',
        '--path',
        projectPath,
        '--clean',
      ]);

      expect(code, 0);
      expect(Directory(workspace.directory).existsSync(), isFalse);
    });

    test('keeps the workspace without --clean', () async {
      await runPrompt();
      writeDrafts();
      await CliRunner().run(['assemble', '--path', projectPath]);

      expect(Directory(workspace.directory).existsSync(), isTrue);
    });
  });
}
