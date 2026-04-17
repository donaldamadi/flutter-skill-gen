import * as vscode from 'vscode';
import { exec, ChildProcess, ExecException } from 'child_process';

/** Result of running a CLI command. */
export interface CliResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

/**
 * Thin wrapper around the `flutter_skill_gen` CLI.
 *
 * Every public method shells out to the Dart CLI binary,
 * keeping the extension a pure presentation layer with zero
 * business logic duplication.
 */
export class FlutterSkillCli {
  private getCliPath(): string {
    return vscode.workspace
      .getConfiguration('flutterSkill')
      .get<string>('cliPath', 'flutter_skill_gen');
  }

  private getCwd(): string | undefined {
    return vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
  }

  /** Run a CLI command and return the result. */
  run(args: string): Promise<CliResult> {
    const cli = this.getCliPath();
    const cwd = this.getCwd();

    return new Promise((resolve) => {
      exec(
        `${cli} ${args}`,
        { cwd, timeout: 120_000 },
        (error: ExecException | null, stdout: string, stderr: string) => {
          resolve({
            stdout: stdout.trim(),
            stderr: stderr.trim(),
            exitCode: error?.code ?? 0,
          });
        },
      );
    });
  }

  /** Run analyze on the current workspace. */
  analyze(): Promise<CliResult> {
    return this.run('analyze --verbose');
  }

  /** Run sync on the current workspace. */
  sync(): Promise<CliResult> {
    return this.run('sync --verbose');
  }

  /** Install git hooks. */
  installHooks(): Promise<CliResult> {
    return this.run('hooks --install');
  }

  /** Generate GitHub Action. */
  generateAction(): Promise<CliResult> {
    return this.run('hooks --github-action');
  }

  /**
   * Start watch mode as a long-running background process.
   * Returns the child process so it can be killed later.
   */
  startWatch(): ChildProcess | undefined {
    const cli = this.getCliPath();
    const cwd = this.getCwd();
    if (!cwd) {
      return undefined;
    }

    const child = exec(`${cli} watch --verbose`, { cwd });
    return child;
  }
}
