import 'package:flutter/foundation.dart';

/// Production-safe logging utility
/// By default logs only in debug/profile. To enable logs in release, pass:
///   --dart-define=ENABLE_LOGS=true
class AppLogger {
 static const bool _enableLogs = bool.fromEnvironment('ENABLE_LOGS', defaultValue: false);

 static void log(String message, [String? tag]) {
   // Log in debug, profile, or when explicitly enabled via dart-define
   if (kDebugMode || kProfileMode || _enableLogs) {
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