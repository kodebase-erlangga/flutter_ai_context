/// CLI logging with normal, verbose, and quiet modes.
enum LogLevel { quiet, normal, verbose }

class Logger {
  Logger({this.level = LogLevel.normal});

  LogLevel level;

  void info(String message) {
    if (level == LogLevel.quiet) return;
    // ignore: avoid_print
    print(message);
  }

  void success(String message) {
    if (level == LogLevel.quiet) return;
    // ignore: avoid_print
    print('✓ $message');
  }

  void warn(String message) {
    if (level == LogLevel.quiet) return;
    // ignore: avoid_print
    print('⚠ $message');
  }

  void error(String message) {
    // ignore: avoid_print
    print('✗ $message');
  }

  void debug(String message) {
    if (level != LogLevel.verbose) return;
    // ignore: avoid_print
    print('[DEBUG] $message');
  }

  void blank() {
    if (level == LogLevel.quiet) return;
    // ignore: avoid_print
    print('');
  }
}
