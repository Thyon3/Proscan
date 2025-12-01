import 'dart:developer' as developer;

class AppLogger {
  const AppLogger._();

  static void info(String message, {Map<String, dynamic>? data}) {
    developer.log(message, level: 800, name: 'ThyScan', error: data);
  }

  static void warning(String message, {Map<String, dynamic>? data}) {
    developer.log(message, level: 900, name: 'ThyScan', error: data);
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stack,
    Map<String, dynamic>? data,
  }) {
    developer.log(
      message,
      level: 1000,
      name: 'ThyScan',
      error: error ?? data,
      stackTrace: stack,
    );
  }

  static void performance(
    String operation,
    Duration duration, {
    Map<String, dynamic>? data,
  }) {
    developer.log(
      'Performance: $operation took ${duration.inMilliseconds}ms',
      level: 700,
      name: 'ThyScan::Performance',
      error: data,
    );
  }
}
