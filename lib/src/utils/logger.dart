import 'dart:io';

/// Simple logger for CLI output with severity levels.
class Logger {
  /// Creates a [Logger] with optional [verbose] mode.
  const Logger({this.verbose = false});

  /// Whether to print debug-level messages.
  final bool verbose;

  /// Logs an informational message.
  void info(String message) {
    stdout.writeln(message);
  }

  /// Logs a success message.
  void success(String message) {
    stdout.writeln('[OK] $message');
  }

  /// Logs a warning message.
  void warn(String message) {
    stderr.writeln('[WARN] $message');
  }

  /// Logs an error message.
  void error(String message) {
    stderr.writeln('[ERROR] $message');
  }

  /// Logs a debug message (only if [verbose] is true).
  void debug(String message) {
    if (verbose) {
      stdout.writeln('[DEBUG] $message');
    }
  }
}
