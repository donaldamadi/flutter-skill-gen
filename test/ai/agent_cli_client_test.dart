import 'dart:convert';
import 'dart:io';

import 'package:flutter_skill_gen/src/ai/agent_cli_client.dart';
import 'package:flutter_skill_gen/src/ai/llm_client.dart';
import 'package:test/test.dart';

/// Builds a stub invoker that always returns [stdout].
CliInvoker _stubbing(
  String stdout, {
  int exitCode = 0,
  String stderr = '',
  void Function(String executable, List<String> args, String stdin)? capture,
}) {
  return (
    String executable,
    List<String> arguments, {
    required String stdin,
    required String workingDirectory,
  }) async {
    capture?.call(executable, arguments, stdin);
    return CliInvocation(exitCode: exitCode, stdout: stdout, stderr: stderr);
  };
}

String _resultJson(String text, {bool isError = false, String? subtype}) =>
    jsonEncode({
      'type': 'result',
      'subtype': subtype ?? 'success',
      'is_error': isError,
      'result': text,
    });

void main() {
  group('AgentCliClient', () {
    group('invocation', () {
      test('runs claude in print mode with JSON output', () async {
        late String executable;
        late List<String> args;

        final client = AgentCliClient(
          agent: AgentCli.claudeCode,
          model: 'opus',
          invoker: _stubbing(
            _resultJson('# Skill'),
            capture: (exe, a, _) {
              executable = exe;
              args = a;
            },
          ),
        );

        await client.complete(
          systemPrompt: 'You are an architect.',
          userMessage: 'Generate it.',
        );

        expect(executable, 'claude');
        expect(args, containsAllInOrder(['--print']));
        expect(args, containsAllInOrder(['--output-format', 'json']));
        expect(args, containsAllInOrder(['--model', 'opus']));
        expect(
          args,
          containsAllInOrder(['--system-prompt', 'You are an architect.']),
        );
      });

      test('passes the user message on stdin, not as an argument', () async {
        // A full facts payload is megabytes; as argv it would blow
        // past the platform argument limit.
        final userMessage = 'x' * 4096;
        late String capturedStdin;
        late List<String> args;

        final client = AgentCliClient(
          agent: AgentCli.claudeCode,
          invoker: _stubbing(
            _resultJson('# Skill'),
            capture: (_, a, stdin) {
              args = a;
              capturedStdin = stdin;
            },
          ),
        );

        await client.complete(systemPrompt: 'sys', userMessage: userMessage);

        expect(capturedStdin, userMessage);
        expect(args, isNot(contains(userMessage)));
      });

      test('denies the tools that could touch the project', () async {
        late List<String> args;

        final client = AgentCliClient(
          agent: AgentCli.claudeCode,
          invoker: _stubbing(
            _resultJson('# Skill'),
            capture: (_, a, __) => args = a,
          ),
        );

        await client.complete(systemPrompt: 'sys', userMessage: 'msg');

        final index = args.indexOf('--disallowed-tools');
        expect(index, greaterThan(-1));
        final denied = args[index + 1].split(',');
        expect(denied, containsAll(['Bash', 'Edit', 'Write']));
      });

      test('forwards extra args', () async {
        late List<String> args;

        final client = AgentCliClient(
          agent: AgentCli.claudeCode,
          extraArgs: const ['--add-dir', '/tmp/x'],
          invoker: _stubbing(
            _resultJson('# Skill'),
            capture: (_, a, __) => args = a,
          ),
        );

        await client.complete(systemPrompt: 'sys', userMessage: 'msg');

        expect(args, containsAllInOrder(['--add-dir', '/tmp/x']));
      });

      test('runs in a scratch directory, not the project', () async {
        // The prompt already carries every fact, so the CLI has no
        // reason to read the project — and from a scratch directory
        // it cannot reach it even if it tried.
        late String captured;

        final client = AgentCliClient(
          agent: AgentCli.claudeCode,
          invoker:
              (
                String executable,
                List<String> arguments, {
                required String stdin,
                required String workingDirectory,
              }) async {
                captured = workingDirectory;
                return CliInvocation(
                  exitCode: 0,
                  stdout: _resultJson('# Skill'),
                  stderr: '',
                );
              },
        );

        await client.complete(systemPrompt: 'sys', userMessage: 'msg');

        expect(captured, isNot(Directory.current.path));
        expect(Directory(captured).existsSync(), isTrue);

        client.close();
        expect(Directory(captured).existsSync(), isFalse);
      });

      test('uses the injected working directory', () async {
        late String captured;

        final client = AgentCliClient(
          agent: AgentCli.claudeCode,
          workingDirectory: '/tmp/scratch-dir',
          invoker:
              (
                String executable,
                List<String> arguments, {
                required String stdin,
                required String workingDirectory,
              }) async {
                captured = workingDirectory;
                return CliInvocation(
                  exitCode: 0,
                  stdout: _resultJson('# Skill'),
                  stderr: '',
                );
              },
        );

        await client.complete(systemPrompt: 'sys', userMessage: 'msg');

        expect(captured, '/tmp/scratch-dir');
      });
    });

    group('result parsing', () {
      test('returns the result field', () async {
        final client = AgentCliClient(
          agent: AgentCli.claudeCode,
          invoker: _stubbing(_resultJson('# Project Overview\n\nText.')),
        );

        final content = await client.complete(
          systemPrompt: 'sys',
          userMessage: 'msg',
        );

        expect(content, '# Project Overview\n\nText.');
      });

      test('strips a fence wrapping the whole response', () async {
        // An agent CLI is far more inclined than a raw API to wrap its
        // answer; left in place the fence lands inside SKILL.md.
        final client = AgentCliClient(
          agent: AgentCli.claudeCode,
          invoker: _stubbing(
            _resultJson('```markdown\n## Architecture\n\nText.\n```'),
          ),
        );

        final content = await client.complete(
          systemPrompt: 'sys',
          userMessage: 'msg',
        );

        expect(content, '## Architecture\n\nText.');
      });

      test('keeps fences that are part of the content', () async {
        const body = '## Codegen\n\n```bash\ndart run build_runner\n```';
        final client = AgentCliClient(
          agent: AgentCli.claudeCode,
          invoker: _stubbing(_resultJson(body)),
        );

        final content = await client.complete(
          systemPrompt: 'sys',
          userMessage: 'msg',
        );

        expect(content, body);
      });

      test('throws when the CLI reports an error', () async {
        final client = AgentCliClient(
          agent: AgentCli.claudeCode,
          invoker: _stubbing(
            _resultJson(
              'Credit balance too low',
              isError: true,
              subtype: 'error_during_execution',
            ),
          ),
        );

        expect(
          () => client.complete(systemPrompt: 'sys', userMessage: 'msg'),
          throwsA(
            isA<AgentCliException>().having(
              (e) => e.message,
              'message',
              contains('Credit balance too low'),
            ),
          ),
        );
      });

      test('throws on a non-zero exit code', () async {
        final client = AgentCliClient(
          agent: AgentCli.claudeCode,
          invoker: _stubbing('', exitCode: 1, stderr: 'Invalid API key'),
        );

        expect(
          () => client.complete(systemPrompt: 'sys', userMessage: 'msg'),
          throwsA(
            isA<AgentCliException>().having(
              (e) => e.message,
              'message',
              contains('Invalid API key'),
            ),
          ),
        );
      });

      test('accepts plain-text output from a JSON-speaking agent', () async {
        // A build that does not understand the output-format flag
        // still prints a usable answer; refusing it would lose a
        // perfectly good draft.
        final client = AgentCliClient(
          agent: AgentCli.claudeCode,
          invoker: _stubbing('## Overview\n\nPlain text.'),
        );

        expect(
          await client.complete(systemPrompt: 'sys', userMessage: 'msg'),
          '## Overview\n\nPlain text.',
        );
      });

      test('throws on an empty result', () async {
        final client = AgentCliClient(
          agent: AgentCli.claudeCode,
          invoker: _stubbing(_resultJson('  ')),
        );

        expect(
          () => client.complete(systemPrompt: 'sys', userMessage: 'msg'),
          throwsA(isA<AgentCliException>()),
        );
      });

      test('failures are catchable as LlmApiException', () async {
        // This is what makes SkillGenerator fall back to templates
        // when the agent CLI is missing, exactly as for a failing API.
        final client = AgentCliClient(
          agent: AgentCli.claudeCode,
          invoker: _stubbing('', exitCode: 127, stderr: 'not found'),
        );

        expect(
          () => client.complete(systemPrompt: 'sys', userMessage: 'msg'),
          throwsA(isA<LlmApiException>()),
        );
      });
    });

    group('codex', () {
      test('runs codex exec in a read-only sandbox, prompt on stdin', () async {
        late List<String> args;
        late String stdin;

        final client = AgentCliClient(
          agent: AgentCli.codex,
          model: 'gpt-5.6-sol',
          invoker: _stubbing(
            '# Skill',
            capture: (_, a, s) {
              args = a;
              stdin = s;
            },
          ),
        );

        await client.complete(systemPrompt: 'RULES', userMessage: 'FACTS');

        expect(args.first, 'exec');
        expect(args, containsAllInOrder(['--sandbox', 'read-only']));
        expect(args, containsAllInOrder(['--model', 'gpt-5.6-sol']));
        // `-` tells codex to read the prompt from stdin.
        expect(args.last, '-');
        // No system-prompt flag exists, so the rules must travel with
        // the prompt or the draft loses its grounding instructions.
        expect(stdin, startsWith('RULES'));
        expect(stdin, contains('FACTS'));
      });

      test('reads plain-text output', () async {
        final client = AgentCliClient(
          agent: AgentCli.codex,
          invoker: _stubbing('## Architecture\n\nText.'),
        );

        expect(
          await client.complete(systemPrompt: 's', userMessage: 'm'),
          '## Architecture\n\nText.',
        );
      });
    });

    group('gemini-cli', () {
      test('runs headless with JSON output', () async {
        late List<String> args;
        late String stdin;

        final client = AgentCliClient(
          agent: AgentCli.geminiCli,
          model: 'gemini-3.8-flash',
          invoker: _stubbing(
            jsonEncode({'response': '# Skill'}),
            capture: (_, a, s) {
              args = a;
              stdin = s;
            },
          ),
        );

        await client.complete(systemPrompt: 'RULES', userMessage: 'FACTS');

        expect(args, containsAllInOrder(['--output-format', 'json']));
        expect(args, containsAllInOrder(['--model', 'gemini-3.8-flash']));
        expect(stdin, startsWith('RULES'));
      });

      test('reads the response field', () async {
        final client = AgentCliClient(
          agent: AgentCli.geminiCli,
          invoker: _stubbing(jsonEncode({'response': '## Overview'})),
        );

        expect(
          await client.complete(systemPrompt: 's', userMessage: 'm'),
          '## Overview',
        );
      });

      test('falls back to plain text when JSON output is unsupported', () {
        // Older builds reject --output-format and just print the
        // answer; that answer is still usable.
        final client = AgentCliClient(
          agent: AgentCli.geminiCli,
          invoker: _stubbing('## Overview\n\nPlain text answer.'),
        );

        expect(
          client.complete(systemPrompt: 's', userMessage: 'm'),
          completion('## Overview\n\nPlain text answer.'),
        );
      });
    });

    test('every agent has a distinct executable and env var', () {
      final ids = AgentCli.all.map((a) => a.id).toSet();
      final executables = AgentCli.all.map((a) => a.executable).toSet();
      final envVars = AgentCli.all.map((a) => a.executableEnvVar).toSet();

      expect(ids, hasLength(AgentCli.all.length));
      expect(executables, hasLength(AgentCli.all.length));
      expect(envVars, hasLength(AgentCli.all.length));
    });

    test('resolveExecutable honours each agent env var', () {
      for (final agent in AgentCli.all) {
        expect(
          AgentCliClient.resolveExecutable(agent, {
            agent.executableEnvVar: '/opt/bin/${agent.id}',
          }),
          '/opt/bin/${agent.id}',
        );
        expect(
          AgentCliClient.resolveExecutable(agent, const {}),
          agent.executable,
        );
      }
    });

    test('reports unavailability for a nonexistent executable', () {
      expect(
        AgentCliClient.isAvailable(
          executable: 'definitely-not-a-real-binary-xyz',
        ),
        isFalse,
      );
    });
  });
}
