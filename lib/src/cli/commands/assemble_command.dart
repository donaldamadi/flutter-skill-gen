import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../config/skillrc.dart';
import '../../generators/facts_writer.dart';
import '../../generators/manifest_generator.dart';
import '../../generators/skill_generator.dart';
import '../../generators/split_planner.dart';
import '../../models/project_facts.dart';
import '../../output/target_writer.dart';
import '../../skill/skill_workspace.dart';
import '../../utils/logger.dart';
import '../../verifier/draft_verifier.dart';

/// CLI command that turns externally written drafts into finished
/// skill files.
///
/// The back half of the `prompt` → write drafts → `assemble` loop.
/// Every draft is verified against the evidence bundle captured by
/// `prompt`, so a draft written by an agent is held to the same
/// grounding standard as one returned by a provider API.
class AssembleCommand extends Command<int> {
  /// Creates an [AssembleCommand].
  AssembleCommand() {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Path to the Flutter project.',
        defaultsTo: '.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help:
            'Output directory for generated files. '
            'Defaults to the project path.',
      )
      ..addOption(
        'work-dir',
        help:
            'Directory holding the prompts and drafts. '
            'Defaults to ${SkillWorkspace.defaultDirName}/ inside the '
            'project.',
      )
      ..addFlag(
        'clean',
        help: 'Delete the work directory after a successful assemble.',
      )
      ..addFlag('verbose', abbr: 'v', help: 'Enable verbose logging.');
  }

  @override
  String get name => 'assemble';

  @override
  String get description =>
      'Verify externally written drafts and write the final skill '
      'files to every configured output target.';

  @override
  FutureOr<int>? run() async {
    final results = argResults!;
    final projectPath = p.normalize(p.absolute(results.option('path')!));
    final outputDir = results.option('output') ?? projectPath;
    final verbose = results.flag('verbose');

    final logger = Logger(verbose: verbose);

    final workDir =
        results.option('work-dir') ??
        p.join(projectPath, SkillWorkspace.defaultDirName);
    final workspace = SkillWorkspace(
      directory: p.normalize(p.absolute(workDir)),
    );

    final WorkspacePlan recorded;
    final SkillPlan plan;
    final ProjectFacts facts;
    try {
      recorded = workspace.readPlan();
      facts = workspace.readFacts();
      // Replay the planner rather than serialising every SkillSpec:
      // the domain facts each spec carries are rebuilt from the same
      // tree with the same flag, so the scopes come back identical.
      plan = const SplitPlanner().plan(
        facts,
        projectPath: recorded.projectPath,
        forceSplit: recorded.forceSplit,
      );
    } on WorkspaceException catch (e) {
      logger.error(e.message);
      return 66;
    }

    final scopes = plan.specs.map((s) => s.skillName).toList();
    _warnOnScopeDrift(recorded.scopes, scopes, logger);

    final drafts = workspace.readDrafts(scopes);
    final missing = scopes.where((s) => !drafts.containsKey(s)).toList();
    if (missing.isNotEmpty) {
      logger.error(
        'No draft for ${missing.length} scope(s): '
        '${missing.join(', ')}.\n'
        'Write each one to ${workspace.draftsDir}/<scope>.md, then '
        'run assemble again.',
      );
      return 65;
    }

    final skillGen = SkillGenerator(logger: logger);
    final Map<String, String> skills;
    try {
      // Mirror `analyze`: a single-file plan goes through the
      // single-skill path, so the same project assembled and analyzed
      // lands on the same frontmatter name and paths.
      skills = plan.isSplit
          ? skillGen.assembleAll(plan, facts, drafts)
          : {scopes.first: skillGen.assemble(facts, drafts[scopes.first]!)};
    } on DraftVerificationFailedException catch (e) {
      logger
        ..error(e.toString())
        ..error(
          'Fix the offending claims in '
          '${workspace.draftsDir}/ and run assemble again.',
        );
      return 1;
    }

    final factsPath = FactsWriter.write(facts, outputDir: outputDir);
    logger.success('Generated $factsPath');

    final manifestPath = ManifestGenerator.write(
      facts,
      outputDir: outputDir,
      plan: plan,
    );
    logger.success('Generated $manifestPath');

    final rcConfig = Skillrc(projectPath: projectPath).read();
    final targetWriter = TargetWriter(logger: logger);

    if (plan.isSplit) {
      targetWriter.writeMultiSkill(
        skills,
        projectPath: outputDir,
        config: rcConfig,
      );
    } else {
      targetWriter.writeToTargets(
        skills[scopes.first]!,
        projectPath: outputDir,
        config: rcConfig,
      );
    }

    logger.success(
      'Assembled ${skills.length} skill file(s) into '
      '${rcConfig.outputTargets.length} output target(s)',
    );

    if (results.flag('clean')) {
      workspace.delete();
      logger.info('Removed ${workspace.directory}');
    }

    return 0;
  }

  /// Warns when the replayed plan no longer matches what `prompt`
  /// recorded — which means the project changed in between, and the
  /// drafts describe a tree that no longer exists.
  void _warnOnScopeDrift(
    List<String> recorded,
    List<String> current,
    Logger logger,
  ) {
    if (recorded.isEmpty) return;
    final added = current.where((s) => !recorded.contains(s)).toList();
    final removed = recorded.where((s) => !current.contains(s)).toList();
    if (added.isEmpty && removed.isEmpty) return;

    final parts = <String>[
      if (added.isNotEmpty) 'new: ${added.join(', ')}',
      if (removed.isNotEmpty) 'gone: ${removed.join(', ')}',
    ];

    logger.warn(
      'The project changed since "prompt" ran (${parts.join('; ')}). '
      'Re-run "flutter_skill_gen prompt" for an accurate scan.',
    );
  }
}
