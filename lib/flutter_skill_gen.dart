/// A CLI tool that automatically generates SKILL.md files for Flutter
/// projects, giving AI coding assistants full project context from the
/// first prompt.
library;

export 'src/ai/claude_client.dart';
export 'src/ai/prompt_builder.dart';
export 'src/analyzers/code_sampler.dart';
export 'src/analyzers/pattern_detector.dart';
export 'src/analyzers/pubspec_analyzer.dart';
export 'src/analyzers/structure_analyzer.dart';
export 'src/ci/git_hooks_installer.dart';
export 'src/ci/github_action_generator.dart';
export 'src/config/config_manager.dart';
export 'src/config/skillrc.dart';
export 'src/generators/facts_writer.dart';
export 'src/generators/manifest_generator.dart';
export 'src/generators/skill_generator.dart';
export 'src/generators/template_generator.dart';
export 'src/models/convention_info.dart';
export 'src/models/dependency_info.dart';
export 'src/models/pattern_info.dart';
export 'src/models/project_facts.dart';
export 'src/models/structure_info.dart';
export 'src/output/target_writer.dart';
export 'src/router/manifest_reader.dart';
export 'src/router/skill_router.dart';
export 'src/scanner/project_scanner.dart';
export 'src/templates/template_scaffolder.dart';
