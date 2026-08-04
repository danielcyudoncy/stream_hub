import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class LoggingService {
  void debug(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _log('DEBUG', message, tag: tag, error: error, stackTrace: stackTrace);
    }
  }

  void info(String message, {String? tag}) {
    _log('INFO', message, tag: tag);
  }

  void warning(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('WARNING', message, tag: tag, error: error, stackTrace: stackTrace);
  }

  void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('ERROR', message, tag: tag, error: error, stackTrace: stackTrace);
  }

  void _log(String level, String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    final logTag = tag != null ? '[$tag]' : '[App]';
    final formattedMessage = '$level $logTag: $message';

    // In debug builds, mirror to the console so logs are visible in logcat
    // during on-device testing (developer.log only reaches the VM service).
    if (kDebugMode) {
      debugPrint(formattedMessage);
    }

    developer.log(
      formattedMessage,
      name: 'StreamHubPro',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
