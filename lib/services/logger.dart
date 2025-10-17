import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class AppLogger {
  static void info(String message, {Object? data}) {
    _print('INFO', message, data: data);
  }

  static void debug(String message, {Object? data}) {
    if (kDebugMode) {
      _print('DEBUG', message, data: data);
    }
  }

  static void warn(String message, {Object? data}) {
    _print('WARN', message, data: data);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace, Object? data}) {
    _print('ERROR', message, error: error, stackTrace: stackTrace, data: data);
  }

  static void exception(String message, Object error, [StackTrace? stackTrace]) {
    _print('EXCEPTION', message, error: error, stackTrace: stackTrace);
  }

  static void _print(String level, String message, {Object? error, StackTrace? stackTrace, Object? data}) {
    final time = DateTime.now().toIso8601String();
    final buffer = StringBuffer('[$time][$level] $message');
    if (data != null) buffer.write(' | data=$data');
    if (error != null) buffer.write(' | error=$error');
    final out = buffer.toString();
    if (kDebugMode) {
      // debugPrint avoids truncation for long logs
      debugPrint(out);
      if (stackTrace != null) debugPrint(stackTrace.toString());
    }
    // Also send to developer.log for structured tools integration
    developer.log(message, name: 'AppLogger.$level', error: error, stackTrace: stackTrace);
  }
}

