import * as vscode from 'vscode';
import * as path from 'path';
import { ChildProcess } from 'child_process';
import { FlutterSkillCli } from './cli';
import { StatusBar } from './status-bar';

let statusBar: StatusBar;
let cli: FlutterSkillCli;
let watchProcess: ChildProcess | undefined;
let outputChannel: vscode.OutputChannel;

export function activate(context: vscode.ExtensionContext): void {
  cli = new FlutterSkillCli();
  statusBar = new StatusBar();
  outputChannel = vscode.window.createOutputChannel('Flutter Skill');

  statusBar.show();

  // Register commands.
  context.subscriptions.push(
    vscode.commands.registerCommand(
      'flutterSkill.analyze',
      cmdAnalyze,
    ),
    vscode.commands.registerCommand(
      'flutterSkill.sync',
      cmdSync,
    ),
    vscode.commands.registerCommand(
      'flutterSkill.watch',
      cmdWatch,
    ),
    vscode.commands.registerCommand(
      'flutterSkill.stopWatch',
      cmdStopWatch,
    ),
    vscode.commands.registerCommand(
      'flutterSkill.previewSkill',
      cmdPreviewSkill,
    ),
    vscode.commands.registerCommand(
      'flutterSkill.installHooks',
      cmdInstallHooks,
    ),
    vscode.commands.registerCommand(
      'flutterSkill.generateAction',
      cmdGenerateAction,
    ),
    statusBar,
    outputChannel,
  );
}

export function deactivate(): void {
  stopWatchProcess();
}

// ── Commands ──────────────────────────────────────────────

async function cmdAnalyze(): Promise<void> {
  statusBar.setSyncing();
  outputChannel.show(true);
  outputChannel.appendLine('[flutter_skill_gen] Running analyze...');

  const result = await cli.analyze();

  outputChannel.appendLine(result.stdout);
  if (result.stderr) {
    outputChannel.appendLine(result.stderr);
  }

  if (result.exitCode === 0) {
    statusBar.setIdle();
    vscode.window.showInformationMessage(
      'Flutter Skill: Analysis complete.',
    );
  } else {
    statusBar.setError('Analysis failed');
    vscode.window.showErrorMessage(
      `Flutter Skill: Analysis failed (exit ${result.exitCode}).`,
    );
  }
}

async function cmdSync(): Promise<void> {
  statusBar.setSyncing();
  outputChannel.show(true);
  outputChannel.appendLine('[flutter_skill_gen] Running sync...');

  const result = await cli.sync();

  outputChannel.appendLine(result.stdout);
  if (result.stderr) {
    outputChannel.appendLine(result.stderr);
  }

  if (result.exitCode === 0) {
    statusBar.setIdle();
    vscode.window.showInformationMessage(
      'Flutter Skill: Sync complete.',
    );
  } else {
    statusBar.setError('Sync failed');
    vscode.window.showErrorMessage(
      `Flutter Skill: Sync failed (exit ${result.exitCode}).`,
    );
  }
}

async function cmdWatch(): Promise<void> {
  if (watchProcess) {
    vscode.window.showInformationMessage(
      'Flutter Skill: Watch mode is already running.',
    );
    return;
  }

  outputChannel.show(true);
  outputChannel.appendLine(
    '[flutter_skill_gen] Starting watch mode...',
  );

  watchProcess = cli.startWatch();

  if (!watchProcess) {
    statusBar.setError('No workspace');
    vscode.window.showErrorMessage(
      'Flutter Skill: No workspace folder found.',
    );
    return;
  }

  statusBar.setWatching();

  watchProcess.stdout?.on('data', (data: Buffer) => {
    outputChannel.append(data.toString());
  });

  watchProcess.stderr?.on('data', (data: Buffer) => {
    outputChannel.append(data.toString());
  });

  watchProcess.on('exit', (code: number | null) => {
    outputChannel.appendLine(
      `[flutter_skill_gen] Watch exited (code ${code}).`,
    );
    watchProcess = undefined;
    statusBar.setIdle();
  });

  vscode.window.showInformationMessage(
    'Flutter Skill: Watch mode started.',
  );
}

function cmdStopWatch(): void {
  if (!watchProcess) {
    vscode.window.showInformationMessage(
      'Flutter Skill: Watch mode is not running.',
    );
    return;
  }

  stopWatchProcess();
  vscode.window.showInformationMessage(
    'Flutter Skill: Watch mode stopped.',
  );
}

async function cmdPreviewSkill(): Promise<void> {
  const workspaceRoot =
    vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
  if (!workspaceRoot) {
    vscode.window.showErrorMessage(
      'Flutter Skill: No workspace folder found.',
    );
    return;
  }

  // Try SKILL.md first, then CLAUDE.md, then AGENTS.md.
  const candidates = ['SKILL.md', 'CLAUDE.md', 'AGENTS.md'];
  for (const name of candidates) {
    const uri = vscode.Uri.file(path.join(workspaceRoot, name));
    try {
      await vscode.workspace.fs.stat(uri);
      const doc = await vscode.workspace.openTextDocument(uri);
      await vscode.commands.executeCommand(
        'markdown.showPreview',
        doc.uri,
      );
      return;
    } catch {
      // File doesn't exist, try next.
    }
  }

  const action = await vscode.window.showWarningMessage(
    'No skill file found. Run analyze first?',
    'Analyze',
  );
  if (action === 'Analyze') {
    await cmdAnalyze();
  }
}

async function cmdInstallHooks(): Promise<void> {
  outputChannel.show(true);
  outputChannel.appendLine(
    '[flutter_skill_gen] Installing git hooks...',
  );

  const result = await cli.installHooks();

  outputChannel.appendLine(result.stdout);
  if (result.stderr) {
    outputChannel.appendLine(result.stderr);
  }

  if (result.exitCode === 0) {
    vscode.window.showInformationMessage(
      'Flutter Skill: Git hooks installed.',
    );
  } else {
    vscode.window.showErrorMessage(
      'Flutter Skill: Failed to install git hooks.',
    );
  }
}

async function cmdGenerateAction(): Promise<void> {
  outputChannel.show(true);
  outputChannel.appendLine(
    '[flutter_skill_gen] Generating GitHub Action...',
  );

  const result = await cli.generateAction();

  outputChannel.appendLine(result.stdout);
  if (result.stderr) {
    outputChannel.appendLine(result.stderr);
  }

  if (result.exitCode === 0) {
    vscode.window.showInformationMessage(
      'Flutter Skill: GitHub Action generated.',
    );
  } else {
    vscode.window.showErrorMessage(
      'Flutter Skill: Failed to generate GitHub Action.',
    );
  }
}

// ── Helpers ───────────────────────────────────────────────

function stopWatchProcess(): void {
  if (watchProcess) {
    watchProcess.kill();
    watchProcess = undefined;
    statusBar.setIdle();
  }
}
