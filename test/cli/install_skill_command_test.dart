import 'dart:io';

import 'package:flutter_skill_gen/src/cli/cli_runner.dart';
import 'package:flutter_skill_gen/src/skill/agent_skill_asset.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('InstallSkillCommand', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('flutter_skill_gen_install_');
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test('command is registered', () {
      expect(CliRunner().commands.keys, contains('install-skill'));
    });

    String skillAt(String root, String dir) =>
        p.join(root, dir, 'skills', 'flutter-skill-gen', 'SKILL.md');

    test('installs for every agent by default', () async {
      // One command has to leave the skill discoverable by Claude
      // Code (.claude/skills) and by Codex, Gemini CLI and OpenCode
      // (.agents/skills), or most users silently get nothing.
      final code = await CliRunner().run([
        'install-skill',
        '--path',
        temp.path,
      ]);

      expect(code, 0);
      expect(File(skillAt(temp.path, '.claude')).existsSync(), isTrue);
      expect(File(skillAt(temp.path, '.agents')).existsSync(), isTrue);
    });

    test('installs the identical file to every location', () async {
      await CliRunner().run(['install-skill', '--path', temp.path]);

      expect(
        File(skillAt(temp.path, '.agents')).readAsStringSync(),
        File(skillAt(temp.path, '.claude')).readAsStringSync(),
      );
    });

    test('--agent claude installs only the Claude location', () async {
      final code = await CliRunner().run([
        'install-skill',
        '--path',
        temp.path,
        '--agent',
        'claude',
      ]);

      expect(code, 0);
      expect(File(skillAt(temp.path, '.claude')).existsSync(), isTrue);
      expect(File(skillAt(temp.path, '.agents')).existsSync(), isFalse);
    });

    test('codex, gemini and opencode all map to .agents/skills', () async {
      for (final agent in ['codex', 'gemini', 'opencode']) {
        final dir = Directory(p.join(temp.path, agent))..createSync();
        final code = await CliRunner().run([
          'install-skill',
          '--path',
          dir.path,
          '--agent',
          agent,
        ]);

        expect(code, 0, reason: agent);
        expect(
          File(skillAt(dir.path, '.agents')).existsSync(),
          isTrue,
          reason: '$agent should install into .agents/skills',
        );
        expect(File(skillAt(dir.path, '.claude')).existsSync(), isFalse);
      }
    });

    test('rejects an unknown agent', () async {
      final code = await CliRunner().run([
        'install-skill',
        '--path',
        temp.path,
        '--agent',
        'notepad',
      ]);

      expect(code, 64);
      expect(File(skillAt(temp.path, '.claude')).existsSync(), isFalse);
    });

    test('installs nothing when one target is blocked', () async {
      // All-or-nothing: a half-installed skill would be discoverable
      // by one agent and stale for another.
      await CliRunner().run(['install-skill', '--path', temp.path]);
      File(skillAt(temp.path, '.claude')).writeAsStringSync('hand-edited');
      File(skillAt(temp.path, '.agents')).deleteSync();

      final code = await CliRunner().run([
        'install-skill',
        '--path',
        temp.path,
      ]);

      expect(code, 73);
      expect(File(skillAt(temp.path, '.agents')).existsSync(), isFalse);
      expect(
        File(skillAt(temp.path, '.claude')).readAsStringSync(),
        'hand-edited',
      );
    });

    test('--output installs into an explicit directory', () async {
      final custom = p.join(temp.path, 'somewhere');
      final code = await CliRunner().run(['install-skill', '--output', custom]);

      expect(code, 0);
      expect(File(p.join(custom, 'SKILL.md')).existsSync(), isTrue);
    });

    test('refuses to overwrite without --force', () async {
      final custom = p.join(temp.path, 'somewhere');
      await CliRunner().run(['install-skill', '--output', custom]);

      File(p.join(custom, 'SKILL.md')).writeAsStringSync('hand-edited');

      final code = await CliRunner().run(['install-skill', '--output', custom]);

      expect(code, 73);
      expect(
        File(p.join(custom, 'SKILL.md')).readAsStringSync(),
        'hand-edited',
      );
    });

    test('--force overwrites', () async {
      final custom = p.join(temp.path, 'somewhere');
      await CliRunner().run(['install-skill', '--output', custom]);
      File(p.join(custom, 'SKILL.md')).writeAsStringSync('hand-edited');

      final code = await CliRunner().run([
        'install-skill',
        '--output',
        custom,
        '--force',
      ]);

      expect(code, 0);
      expect(
        File(p.join(custom, 'SKILL.md')).readAsStringSync(),
        isNot('hand-edited'),
      );
    });
  });

  group('AgentSkillAsset', () {
    test('carries spec-compliant frontmatter', () {
      expect(AgentSkillAsset.content, startsWith('---\n'));
      expect(AgentSkillAsset.content, contains('name: flutter-skill-gen'));
      expect(AgentSkillAsset.content, contains('description:'));
    });

    test('describes the full prompt-draft-assemble loop', () {
      // If the skill omits a step, the agent stalls halfway through.
      expect(AgentSkillAsset.content, contains('flutter_skill_gen prompt'));
      expect(AgentSkillAsset.content, contains('flutter_skill_gen assemble'));
      expect(AgentSkillAsset.content, contains('drafts/'));
    });

    test('tells the agent how to install the CLI', () {
      expect(
        AgentSkillAsset.content,
        contains('dart pub global activate flutter_skill_gen'),
      );
    });

    test('only tells the agent to run flags the CLI accepts', () {
      // Regression: the skill once opened with `--version`, which the
      // CLI rejects with a usage error — the agent's very first
      // command failed. Every global flag the skill names must exist.
      final parser = CliRunner().argParser;
      final flags = RegExp('flutter_skill_gen (--[a-z-]+)')
          .allMatches(AgentSkillAsset.content)
          .map((m) => m.group(1)!.substring(2))
          .toSet();

      expect(flags, isNotEmpty);
      for (final flag in flags) {
        expect(
          parser.options.containsKey(flag),
          isTrue,
          reason: 'skill tells the agent to run --$flag, which does not exist',
        );
      }
    });

    test('only names commands the CLI registers', () {
      final commands = CliRunner().commands.keys.toSet();
      final named = RegExp('flutter_skill_gen ([a-z][a-z-]+)')
          .allMatches(AgentSkillAsset.content)
          .map((m) => m.group(1)!)
          .where((word) => !{'scans', 'is'}.contains(word))
          .toSet();

      expect(named, isNotEmpty);
      for (final command in named) {
        expect(
          commands,
          contains(command),
          reason: 'skill names "$command", which is not a command',
        );
      }
    });

    test('warns against the mistakes that corrupt output', () {
      expect(AgentSkillAsset.content, contains('frontmatter'));
      expect(AgentSkillAsset.content, contains('Gotchas'));
      expect(AgentSkillAsset.content, contains('line budget'));
    });

    test('resolves a project directory per location', () {
      expect(
        AgentSkillAsset.projectDir('/tmp/app'),
        p.join('/tmp/app', '.claude', 'skills', 'flutter-skill-gen'),
      );
      expect(
        AgentSkillAsset.projectDir('/tmp/app', location: SkillLocation.agents),
        p.join('/tmp/app', '.agents', 'skills', 'flutter-skill-gen'),
      );
    });

    test('resolves a global directory per location', () {
      expect(
        AgentSkillAsset.globalDir(environment: {'HOME': '/home/dev'}),
        p.join('/home/dev', '.claude', 'skills', 'flutter-skill-gen'),
      );
      expect(
        AgentSkillAsset.globalDir(
          location: SkillLocation.agents,
          environment: {'HOME': '/home/dev'},
        ),
        p.join('/home/dev', '.agents', 'skills', 'flutter-skill-gen'),
      );
    });

    test('is written for any agent, not just Claude Code', () {
      // The skill now ships to Codex, Gemini CLI and OpenCode too, so
      // no step may assume the agent reading it is Claude Code. The
      // one allowed mention is the list of output formats, where
      // "Claude Code" is the name of a target file format.
      final offending = AgentSkillAsset.content
          .split('\n')
          .where((line) => line.contains('Claude Code'))
          .where((line) => !line.contains('Cursor'))
          .toList();

      expect(
        offending,
        isEmpty,
        reason: 'these lines assume the reader is Claude Code',
      );
    });

    test('tells the agent what to do when run as a dev dependency', () {
      expect(AgentSkillAsset.content, contains('dart run flutter_skill_gen'));
    });
  });
}
