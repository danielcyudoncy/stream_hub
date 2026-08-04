import 'package:flutter/foundation.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';

/// The action taken by the error recovery engine.
enum RecoveryAction {
  none,
  retry,
  refreshAuthentication,
  selectBackup,
  reResolve,
  refreshSession,
  invalidateCache;

  String get displayName {
    switch (this) {
      case RecoveryAction.none:
        return 'None';
      case RecoveryAction.retry:
        return 'Retry';
      case RecoveryAction.refreshAuthentication:
        return 'Refresh Authentication';
      case RecoveryAction.selectBackup:
        return 'Select Backup URL';
      case RecoveryAction.reResolve:
        return 'Re-resolve Stream';
      case RecoveryAction.refreshSession:
        return 'Refresh Session';
      case RecoveryAction.invalidateCache:
        return 'Invalidate Cache';
    }
  }
}

/// The outcome of an error recovery attempt.
@immutable
class RecoveryResult {
  final bool recovered;
  final RecoveryAction action;
  final int attempts;
  final String message;
  final PlayableSession? finalSession;
  final List<String> attemptLog;

  const RecoveryResult({
    required this.recovered,
    required this.action,
    required this.attempts,
    required this.message,
    this.finalSession,
    this.attemptLog = const [],
  });

  const RecoveryResult.unrecovered({
    this.action = RecoveryAction.none,
    this.attempts = 0,
    this.message = 'No recovery action could be taken.',
    this.finalSession,
    this.attemptLog = const [],
  }) : recovered = false;
}
