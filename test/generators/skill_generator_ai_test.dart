import 'dart:convert';

import 'package:flutter_skill_gen/src/generators/skill_generator.dart';
import 'package:flutter_skill_gen/src/models/convention_info.dart';
import 'package:flutter_skill_gen/src/models/dependency_info.dart';
import 'package:flutter_skill_gen/src/models/pattern_info.dart';
import 'package:flutter_skill_gen/src/models/project_facts.dart';
import 'package:flutter_skill_gen/src/models/structure_info.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:test/test.dart';

ProjectFacts _buildFacts({String projectName = 'test_app'}) {
  return ProjectFacts(
    projectName: projectName,
    dependencies: const DependencyInfo(stateManagement: ['flutter_bloc']),
    structure: const StructureInfo(organization: 'feature-first'),
    patterns: const PatternInfo(
      architecture: 'clean_architecture',
      stateManagement: 'bloc',
    ),
    conventions: const ConventionInfo(),
    generatedAt: '2026-04-16T12:00:00Z',
    toolVersion: '0.1.0',
  );
}

http_testing.MockClient _successClient(String responseText) {
  return http_testing.MockClient((_) async {
    return http.Response(
      jsonEncode({
        'content': [
          {'type': 'text', 'text': responseText},
        ],
      }),
      200,
    );
  });
}

http_testing.MockClient _errorClient(int statusCode) {
  return http_testing.MockClient((_) async {
    return http.Response('{"error": {"message": "test error"}}', statusCode);
  });
}

http_testing.MockClient _networkErrorClient() {
  return http_testing.MockClient((_) async {
    throw Exception('Connection refused');
  });
}

void main() {
  group('SkillGenerator AI path', () {
    test('returns AI-generated content on success', () async {
      const aiContent = '# test_app\n\nAI-generated skill file.';
      final gen = SkillGenerator(
        apiKey: 'sk-ant-test-key',
        httpClient: _successClient(aiContent),
      );

      final result = await gen.generate(_buildFacts());
      // Content should include Agent Skills frontmatter.
      expect(result, contains('---\nname: test-app\n'));
      expect(result, contains('description:'));
      expect(result, contains(aiContent));
    });

    test('sends request with correct model', () async {
      late Map<String, dynamic> capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'ok'},
            ],
          }),
          200,
        );
      });

      final gen = SkillGenerator(
        apiKey: 'sk-ant-test-key',
        model: 'claude-opus-4-20250514',
        httpClient: mockClient,
      );

      await gen.generate(_buildFacts());
      expect(capturedBody['model'], 'claude-opus-4-20250514');
    });

    test('sends system prompt and user message', () async {
      late Map<String, dynamic> capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'ok'},
            ],
          }),
          200,
        );
      });

      final gen = SkillGenerator(
        apiKey: 'sk-ant-test-key',
        httpClient: mockClient,
      );

      await gen.generate(_buildFacts());

      expect(capturedBody['system'], isNotEmpty);
      final messages = capturedBody['messages'] as List<dynamic>;
      expect(messages, hasLength(1));
      final userMsg = messages[0] as Map<String, dynamic>;
      expect(userMsg['role'], 'user');
      expect(userMsg['content'] as String, contains('test_app'));
    });

    test('falls back to template on API error (401)', () async {
      final gen = SkillGenerator(
        apiKey: 'sk-ant-bad-key',
        httpClient: _errorClient(401),
      );

      final result = await gen.generate(_buildFacts());

      // Template fallback produces markdown with project name.
      expect(result, contains('# test_app'));
      expect(result, contains('## Architecture'));
    });

    test('falls back to template on API error (500)', () async {
      final gen = SkillGenerator(
        apiKey: 'sk-ant-test-key',
        httpClient: _errorClient(500),
      );

      final result = await gen.generate(_buildFacts());
      expect(result, contains('# test_app'));
    });

    test('falls back to template on network error', () async {
      final gen = SkillGenerator(
        apiKey: 'sk-ant-test-key',
        httpClient: _networkErrorClient(),
      );

      final result = await gen.generate(_buildFacts());
      expect(result, contains('# test_app'));
    });

    test('prefers AI content over template when API succeeds', () async {
      const unique = 'UNIQUE_AI_MARKER_12345';
      final gen = SkillGenerator(
        apiKey: 'sk-ant-test-key',
        httpClient: _successClient(unique),
      );

      final result = await gen.generate(_buildFacts());
      expect(result, contains(unique));
      // Should NOT contain template output.
      expect(result, isNot(contains('## Architecture')));
    });
  });
}
