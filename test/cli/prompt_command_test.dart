import 'dart:convert';
import 'dart:io';

import 'package:flutter_skill_gen/src/cli/cli_runner.dart';
import 'package:flutter_skill_gen/src/skill/skill_workspace.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'skill_workspace_fixture.dart';

void main() {
  group('PromptCommand', () {
    late Directory temp;
    late String projectPath;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('flutter_skill_gen_prompt_');
      projectPath = copyFixture('sample_bloc_project', temp.path);
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test('command is registered', () {
      expect(CliRunner().commands.keys, contains('prompt'));
    });

    test('fails for a path without pubspec.yaml', () async {
      final empty = Directory(p.join(temp.path, 'empty'))..createSync();
      final code = await CliRunner().run(['prompt', '--path', empty.path]);
      expect(code, 64);
    });

    test('writes a workspace with facts, plan, and prompts', () async {
      final code = await CliRunner().run(['prompt', '--path', projectPath]);
      expect(code, 0);

      final workspace = SkillWorkspace(
        directory: p.join(projectPath, SkillWorkspace.defaultDirName),
      );

      expect(File(workspace.planPath).existsSync(), isTrue);
      expect(File(workspace.factsPath).existsSync(), isTrue);
      expect(Directory(workspace.draftsDir).existsSync(), isTrue);

      final plan = workspace.readPlan();
      expect(plan.scopes, isNotEmpty);
      for (final scope in plan.scopes) {
        expect(
          File(workspace.promptPath(scope)).existsSync(),
          isTrue,
          reason: 'missing prompt for scope "$scope"',
        );
      }
    });

    test('makes no API call and needs no key', () async {
      // The whole point of the agent-driven path: a run that reaches
      // a finished prompt set without any provider credentials.
      final code = await CliRunner().run(['prompt', '--path', projectPath]);
      expect(code, 0);
    });

    test('leaves .skill_facts.json at the project root untouched', () async {
      // A prompt run that is never assembled must not advance the
      // change-detection baseline that `sync` reads, or the next sync
      // would see no change and skip a stale SKILL.md.
      final rootFacts = File(p.join(projectPath, '.skill_facts.json'));
      final before = rootFacts.existsSync()
          ? rootFacts.readAsStringSync()
          : null;

      await CliRunner().run(['prompt', '--path', projectPath]);

      final after = rootFacts.existsSync()
          ? rootFacts.readAsStringSync()
          : null;
      expect(after, before);

      // The scan still has to land somewhere — inside the workspace.
      expect(
        File(
          p.join(projectPath, SkillWorkspace.defaultDirName, 'facts.json'),
        ).existsSync(),
        isTrue,
      );
    });

    test('prompt contains the instructions and the evidence', () async {
      await CliRunner().run(['prompt', '--path', projectPath]);

      final workspace = SkillWorkspace(
        directory: p.join(projectPath, SkillWorkspace.defaultDirName),
      );
      final content = File(
        workspace.promptPath(workspace.readPlan().scopes.first),
      ).readAsStringSync();

      expect(content, contains('# Instructions'));
      expect(content, contains('# Input'));
      // The grounding rules are what the verifier later enforces.
      expect(content, contains('grounding rules'));
      expect(content, contains('evidence'));
      expect(content, contains('Do NOT include YAML frontmatter'));
    });

    test('--split emits one prompt per feature plus core', () async {
      final code = await CliRunner().run([
        'prompt',
        '--path',
        projectPath,
        '--split',
      ]);
      expect(code, 0);

      final workspace = SkillWorkspace(
        directory: p.join(projectPath, SkillWorkspace.defaultDirName),
      );
      final plan = workspace.readPlan();

      expect(plan.isSplit, isTrue);
      expect(plan.scopes.first, 'core');
      expect(plan.scopes.length, greaterThan(1));
    });

    test('records the split flag so assemble can replay it', () async {
      await CliRunner().run(['prompt', '--path', projectPath, '--split']);

      final planJson =
          jsonDecode(
                File(
                  p.join(
                    projectPath,
                    SkillWorkspace.defaultDirName,
                    'plan.json',
                  ),
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;

      expect(planJson['force_split'], isTrue);
      expect(planJson['version'], SkillWorkspace.planVersion);
    });

    test('clears drafts from a previous run', () async {
      await CliRunner().run(['prompt', '--path', projectPath]);

      final workspace = SkillWorkspace(
        directory: p.join(projectPath, SkillWorkspace.defaultDirName),
      );
      final stale = File(workspace.draftPath('core'))
        ..writeAsStringSync('stale draft from an older tree');

      await CliRunner().run(['prompt', '--path', projectPath]);

      expect(stale.existsSync(), isFalse);
    });

    test('--work-dir relocates the workspace', () async {
      final custom = p.join(temp.path, 'handoff');
      final code = await CliRunner().run([
        'prompt',
        '--path',
        projectPath,
        '--work-dir',
        custom,
      ]);

      expect(code, 0);
      expect(File(p.join(custom, 'plan.json')).existsSync(), isTrue);
      expect(
        Directory(
          p.join(projectPath, SkillWorkspace.defaultDirName),
        ).existsSync(),
        isFalse,
      );
    });
  });
}
