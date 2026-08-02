import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/security/sensitive_data_redactor.dart';

/// Configuration for stream failover behavior.
class FailoverPolicy {
  final int maxAttemptsPerUrl;
  final Duration switchDelay;

  const FailoverPolicy({
    this.maxAttemptsPerUrl = 1,
    this.switchDelay = const Duration(milliseconds: 250),
  });
}

/// Selects a working URL from a primary stream and its backups.
///
/// The player never sees backup URLs: [FailoverManager] hides failover behind
/// [PlayableSession] instances so the playback engine only ever receives a
/// valid, playable session.
class FailoverManager {
  final LoggingService _logger;
  final FailoverPolicy _policy;

  FailoverManager({
    LoggingService? logger,
    FailoverPolicy policy = const FailoverPolicy(),
  }) : _logger = logger ?? LoggingService(),
       _policy = policy;

  /// Returns the list of candidate URLs for a session: primary first, then any
  /// backups stored in metadata.
  List<String> candidateUrls(PlayableSession session) {
    final backups = _backupUrls(session);
    if (backups.isEmpty) return [session.streamUrl];
    return [session.streamUrl, ...backups];
  }

  /// Attempts to validate candidates and returns a session pointing at the
  /// first usable URL. Throws when every candidate fails.
  Future<PlayableSession> selectWorking(
    PlayableSession session, {
    required Future<bool> Function(PlayableSession candidate) test,
  }) async {
    final candidates = candidateUrls(session);
    if (candidates.length == 1) return session;

    for (final url in candidates.skip(1)) {
      final candidate = _withUrl(session, url);
      var usable = false;
      try {
        usable = await test(candidate);
      } catch (_) {
        usable = false;
      }
      if (usable) {
        _logger.info(
          'Failover selected backup stream for ${session.providerId}',
          tag: 'FailoverManager',
        );
        return candidate;
      }
      if (_policy.switchDelay > Duration.zero) {
        await Future.delayed(_policy.switchDelay);
      }
    }

    throw const StreamNetworkException(
      message: 'All stream candidates failed.',
      code: 'STREAM_ALL_CANDIDATES_FAILED',
    );
  }

  PlayableSession _withUrl(PlayableSession session, String url) {
    return session.copyWith(
      streamUrl: url,
      metadata: {...session.metadata, 'primaryUrl': session.streamUrl},
    );
  }

  List<String> _backupUrls(PlayableSession session) {
    final raw = session.metadata['backupUrls'];
    if (raw is List) {
      return raw.whereType<String>().toList();
    }
    return const [];
  }

  /// Debug-safe description for logging.
  String describe(PlayableSession session) {
    return SensitiveDataRedactor.redactUrl(session.streamUrl);
  }
}
