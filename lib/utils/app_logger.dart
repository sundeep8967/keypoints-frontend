import 'package:flutter/foundation.dart';

/// Production-safe logging utility
/// Only logs in debug mode, completely silent in production
class AppLogger {
  static void log(String message, [String? tag]) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final logTag = tag != null ? '[$tag]' : '';
      debugPrint('$timestamp $logTag $message');
    }
  }

  static void info(String message) {
    log(message, 'INFO');
  }

  static void error(String message) {
    log(message, 'ERROR');
  }

  static void warning(String message) {
    log(message, 'WARNING');
  }

  static void debug(String message) {
    log(message, 'DEBUG');
  }

  static void success(String message) {
    log(message, 'SUCCESS');
  }
}