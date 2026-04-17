import * as vscode from 'vscode';

/**
 * Manages the Flutter Skill status bar item.
 *
 * Shows the current state: idle, syncing, watching, or error.
 */
export class StatusBar {
  private item: vscode.StatusBarItem;

  constructor() {
    this.item = vscode.window.createStatusBarItem(
      vscode.StatusBarAlignment.Left,
      50,
    );
    this.item.command = 'flutterSkill.sync';
    this.setIdle();
  }

  /** Show the status bar item. */
  show(): void {
    const enabled = vscode.workspace
      .getConfiguration('flutterSkill')
      .get<boolean>('showStatusBar', true);

    if (enabled) {
      this.item.show();
    }
  }

  /** Hide the status bar item. */
  hide(): void {
    this.item.hide();
  }

  /** Set idle state. */
  setIdle(): void {
    this.item.text = '$(book) Skill';
    this.item.tooltip = 'Flutter Skill — click to sync';
    this.item.backgroundColor = undefined;
  }

  /** Set syncing state. */
  setSyncing(): void {
    this.item.text = '$(sync~spin) Skill';
    this.item.tooltip = 'Flutter Skill — syncing...';
    this.item.backgroundColor = undefined;
  }

  /** Set watching state. */
  setWatching(): void {
    this.item.text = '$(eye) Skill';
    this.item.tooltip = 'Flutter Skill — watching for changes';
    this.item.backgroundColor = undefined;
  }

  /** Set error state. */
  setError(message: string): void {
    this.item.text = '$(warning) Skill';
    this.item.tooltip = `Flutter Skill — ${message}`;
    this.item.backgroundColor = new vscode.ThemeColor(
      'statusBarItem.errorBackground',
    );
  }

  /** Dispose the status bar item. */
  dispose(): void {
    this.item.dispose();
  }
}
