import 'package:stream_hub/core/iptv/models/recovery_result.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/security/sensitive_data_redactor.dart';
import 'package:stream_hub/core/streaming/stream_engine.dart';

/// Automatically recovers from common playback failures:
///
/// - Expired session URLs → re-resolve.
/// - HTTP 401/403 or authentication failure → refresh the provider session.
/// - HTTP 404 → fail over to a backup URL.
/// - Timeouts / network errors → retry with the session's retry policy.
/// - Redirect loops → re-resolve without following redirects.
///
/// Recovery never mutates the player; it produces a corrected [PlayableSession]
/// or a [RecoveryResult] explaining why recovery was impossible.
class ErrorRecoveryEngine {
  final StreamEngine _streamEngine;
  final LoggingService _logger;

  ErrorRecoveryEngine({
    required StreamEngine streamEngine,
    LoggingService? logger,
  }) : _streamEngine = streamEngine,
       _logger = logger ?? LoggingService();

  /// Attempts to recover [session] after [error].
  Future<RecoveryResult> recover(
    PlayableSession session,
    Object error, {
    Map<String, dynamic>? itemMetadata,
  }) async {
    final attemptLog = <String>[];
    _logger.debug(
      'Recovery attempt for ${session.sessionId} after $error',
      tag: 'ErrorRecovery',
    );
    final metadata = itemMetadata ??
        Map<String, dynamic>.from(session.metadata)..putIfAbsent(
          'streamUrl',
          () => session.streamUrl,
        );

    // 1. Expired session URL.
    if (session.isExpired) {
      return _reResolve(
        session,
        metadata,
        'Session URL expired; re-resolving stream.',
        attemptLog,
      );
    }

    final statusCode = _extractStatusCode(error);
    if (statusCode != null) {
      return _recoverByStatusCode(
        session,
        metadata,
        statusCode,
        attemptLog,
      );
    }

    if (error is StreamAuthException) {
      return _refreshAndReResolve(
        session,
        metadata,
        'Authentication failed; refreshing session and re-resolving.',
        attemptLog,
      );
    }
    if (error is StreamTimeoutException) {
      return _retry(
        session,
        metadata,
        'Timed out; retrying with session retry policy.',
        attemptLog,
      );
    }
    if (error is StreamSessionExpiredException) {
      return _reResolve(
        session,
        metadata,
        'Stream session expired; re-resolving.',
        attemptLog,
      );
    }
    if (error is StreamRedirectLoopException) {
      return _reResolve(
        session,
        metadata,
        'Redirect loop detected; re-resolving without redirects.',
        attemptLog,
      );
    }
    if (error is StreamNetworkException) {
      return _retry(
        session,
        metadata,
        'Network error; retrying.',
        attemptLog,
      );
    }

    return RecoveryResult.unrecovered(
      message: 'Unhandled failure: ${error.runtimeType} — ${error.toString()}',
      attemptLog: attemptLog,
    );
  }

  Future<RecoveryResult> _recoverByStatusCode(
    PlayableSession session,
    Map<String, dynamic> metadata,
    int statusCode,
    List<String> attemptLog,
  ) {
    switch (statusCode) {
      case 401:
      case 403:
        return _refreshAndReResolve(
          session,
          metadata,
          'HTTP $statusCode — refreshing authentication and re-resolving.',
          attemptLog,
        );
      case 404:
        return _selectBackup(
          session,
          'HTTP 404 — stream not found; trying backup URL.',
          attemptLog,
        );
      case 408:
      case 429:
      case 500:
      case 502:
      case 503:
      case 504:
        return _retry(
          session,
          metadata,
          'HTTP $statusCode — retrying.',
          attemptLog,
        );
      default:
        return Future.value(
          RecoveryResult.unrecovered(
            message: 'HTTP $statusCode is not recoverable.',
            attemptLog: attemptLog,
          ),
        );
    }
  }

  Future<RecoveryResult> _refreshAndReResolve(
    PlayableSession session,
    Map<String, dynamic> metadata,
    String reason,
    List<String> attemptLog,
  ) async {
    attemptLog.add(reason);
    try {
      await _streamEngine.sessionManager.refreshSession(session.providerId);
      attemptLog.add('Provider session refreshed.');
      return await _reResolve(
        session,
        metadata,
        'Re-resolving after authentication refresh.',
        attemptLog,
      );
    } on Exception catch (e) {
      attemptLog.add('Session refresh failed: $e');
      return RecoveryResult.unrecovered(
        message: 'Authentication recovery failed: $e',
        attemptLog: attemptLog,
      );
    }
  }

  Future<RecoveryResult> _reResolve(
    PlayableSession session,
    Map<String, dynamic> metadata,
    String reason,
    List<String> attemptLog,
  ) async {
    attemptLog.add(reason);
    try {
      final reResolved = await _streamEngine.resolvePlayback(
        mediaItemId: session.mediaItemId,
        providerType: session.providerType,
        itemMetadata: metadata,
        providerId: session.providerId,
        fallbackUrl: session.streamUrl,
        useCache: false,
      );
      attemptLog.add(
        'Re-resolved stream: ${SensitiveDataRedactor.redactUrl(reResolved.streamUrl)}',
      );
      return RecoveryResult(
        recovered: true,
        action: RecoveryAction.reResolve,
        attempts: attemptLog.length,
        message: 'Stream re-resolved successfully.',
        finalSession: reResolved,
        attemptLog: attemptLog,
      );
    } on Exception catch (e) {
      attemptLog.add('Re-resolution failed: $e');
      return RecoveryResult.unrecovered(
        message: 'Could not re-resolve the stream: $e',
        attemptLog: attemptLog,
      );
    }
  }

  Future<RecoveryResult> _selectBackup(
    PlayableSession session,
    String reason,
    List<String> attemptLog,
  ) async {
    attemptLog.add(reason);
    final backups = session.metadata['backupUrls'];
    if (backups is! List || backups.isEmpty) {
      return RecoveryResult.unrecovered(
        message: 'No backup URL available for this stream.',
        attemptLog: attemptLog,
      );
    }
    try {
      final selected = await _streamEngine.selectWorkingStream(session);
      attemptLog.add('Backup URL selected and validated.');
      return RecoveryResult(
        recovered: true,
        action: RecoveryAction.selectBackup,
        attempts: attemptLog.length,
        message: 'Playback can continue on a backup stream.',
        finalSession: selected,
        attemptLog: attemptLog,
      );
    } on Exception catch (e) {
      attemptLog.add('Backup selection failed: $e');
      return RecoveryResult.unrecovered(
        message: 'No working backup stream found: $e',
        attemptLog: attemptLog,
      );
    }
  }

  Future<RecoveryResult> _retry(
    PlayableSession session,
    Map<String, dynamic> metadata,
    String reason,
    List<String> attemptLog,
  ) async {
    attemptLog.add(reason);
    final policy = session.retryPolicy;
    if (!policy.isEnabled) {
      return RecoveryResult.unrecovered(
        message: 'Retries are disabled for this stream.',
        attemptLog: attemptLog,
      );
    }
    for (var attempt = 1; attempt <= policy.maxRetries; attempt++) {
      try {
        await Future.delayed(policy.delayForAttempt(attempt - 1));
        final reResolved = await _streamEngine.resolvePlayback(
          mediaItemId: session.mediaItemId,
          providerType: session.providerType,
          itemMetadata: metadata,
          providerId: session.providerId,
          fallbackUrl: session.streamUrl,
          useCache: false,
        );
        attemptLog.add('Retry $attempt succeeded.');
        return RecoveryResult(
          recovered: true,
          action: RecoveryAction.retry,
          attempts: attemptLog.length,
          message: 'Recovered after $attempt retr${attempt == 1 ? 'y' : 'ies'}.',
          finalSession: reResolved,
          attemptLog: attemptLog,
        );
      } on Exception catch (e) {
        attemptLog.add('Retry $attempt failed: $e');
      }
    }
    return RecoveryResult.unrecovered(
      message: 'All retries failed.',
      attemptLog: attemptLog,
    );
  }

  int? _extractStatusCode(Object error) {
    if (error is StreamAuthException) return 401;
    if (error is StreamNotFoundException) return 404;
    if (error is StreamTimeoutException) return null;
    final message = error.toString();
    final match = RegExp(r'\b(4\d\d|5\d\d)\b').firstMatch(message);
    if (match != null) return int.tryParse(match.group(1)!);
    return null;
  }

  /// Helper so callers can classify an error without running recovery.
  String classify(Object error) {
    if (error is StreamAuthException) return 'authentication';
    if (error is StreamNotFoundException) return 'not-found';
    if (error is StreamTimeoutException) return 'timeout';
    if (error is StreamNetworkException) return 'network';
    if (error is StreamRedirectLoopException) return 'redirect-loop';
    if (error is StreamSessionExpiredException) return 'session-expired';
    if (error is StreamUnsupportedProtocolException) return 'protocol';
    return 'unknown';
  }
}
