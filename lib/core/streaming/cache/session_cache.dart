import 'dart:convert';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/models/stream_capabilities.dart';
import 'package:stream_hub/core/streaming/models/stream_retry_policy.dart';
import 'package:stream_hub/core/streaming/security/data_encryption.dart';
import 'package:stream_hub/data/services/provider_session_local_service.dart';

/// Persistent cache for provider sessions, authentication, cookies, tokens,
/// and refresh information.
///
/// Sensitive values are encrypted before they touch disk. The in-memory copy
/// is never logged.
class SessionCache {
  final ProviderSessionLocalService _localService;
  final DataEncryption _encryption;
  final Map<String, ProviderSession> _memory = {};

  SessionCache(this._localService, {DataEncryption? encryption})
    : _encryption =
          encryption ??
          LocalDataObfuscator.fromSeed(DateTime.now().millisecondsSinceEpoch);

  Future<void> saveProviderSession(ProviderSession session) async {
    _memory[session.providerId] = session;
    await _localService.save(_encode(session));
  }

  Future<ProviderSession?> getProviderSession(String providerId) async {
    final cached = _memory[providerId];
    if (cached != null) return cached;

    final model = await _localService.get(providerId);
    if (model == null) return null;

    final session = _decode(model);
    _memory[providerId] = session;
    return session;
  }

  Future<List<ProviderSession>> getAllProviderSessions() async {
    final models = await _localService.getAll();
    final sessions = models.map(_decode).toList();
    for (final session in sessions) {
      _memory[session.providerId] = session;
    }
    return sessions;
  }

  Future<void> deleteProviderSession(String providerId) async {
    _memory.remove(providerId);
    await _localService.delete(providerId);
  }

  Future<void> clear() async {
    _memory.clear();
    await _localService.clear();
  }

  ProviderSessionCacheModel _encode(ProviderSession session) {
    final data = <String, dynamic>{
      'sessionId': _safe(session.sessionId),
      'expiresAt': session.expiresAt?.toIso8601String(),
      'userAgent': _safe(session.userAgent),
      'referer': _safe(session.referer),
      'origin': _safe(session.origin),
      'baseUrl': _safe(session.baseUrl),
      'timeoutMs': session.timeout.inMilliseconds,
      'deviceId': _safe(session.deviceId),
      'retryMaxRetries': session.retryPolicy.maxRetries,
      'retryBaseDelayMs': session.retryPolicy.baseDelay.inMilliseconds,
      'retryMaxDelayMs': session.retryPolicy.maxDelay.inMilliseconds,
      'retryMultiplier': session.retryPolicy.backoffMultiplier,
      'capSeeking': session.capabilities.supportsSeeking,
      'capPause': session.capabilities.supportsPause,
      'capRecording': session.capabilities.supportsRecording,
      'capDownload': session.capabilities.supportsDownload,
      'capCatchup': session.capabilities.supportsCatchup,
      'capTimeshift': session.capabilities.supportsTimeshift,
      'capSubtitles': session.capabilities.supportsSubtitles,
      'capAudioTracks': session.capabilities.supportsAudioTracks,
    };
    data['headers'] = _encryptJson(session.headers);
    data['cookies'] = _encryptJson(session.cookies);
    if (session.bearerToken != null) {
      data['bearerToken'] = _encryption.encrypt(session.bearerToken!);
    }
    if (session.macAddress != null) {
      data['macAddress'] = _encryption.encrypt(session.macAddress!);
    }
    if (session.portalToken != null) {
      data['portalToken'] = _encryption.encrypt(session.portalToken!);
    }
    if (session.username != null) {
      data['username'] = _encryption.encrypt(session.username!);
    }
    if (session.password != null) {
      data['password'] = _encryption.encrypt(session.password!);
    }

    return ProviderSessionCacheModel(
      providerId: session.providerId,
      providerTypeIndex: session.providerType.index,
      sessionId: session.sessionId,
      data: data,
    );
  }

  ProviderSession _decode(ProviderSessionCacheModel model) {
    final data = model.data;

    final expiresAt = _parseDate(data['expiresAt'] as String?);
    final retryPolicy = RetryPolicy(
      maxRetries: (data['retryMaxRetries'] as int?) ?? 3,
      baseDelay: Duration(
        milliseconds: (data['retryBaseDelayMs'] as int?) ?? 500,
      ),
      maxDelay: Duration(
        milliseconds: (data['retryMaxDelayMs'] as int?) ?? 10000,
      ),
      backoffMultiplier: (data['retryMultiplier'] as num?)?.toDouble() ?? 2.0,
    );
    final capabilities = StreamCapabilities(
      supportsSeeking: (data['capSeeking'] as bool?) ?? false,
      supportsPause: (data['capPause'] as bool?) ?? true,
      supportsRecording: (data['capRecording'] as bool?) ?? false,
      supportsDownload: (data['capDownload'] as bool?) ?? false,
      supportsCatchup: (data['capCatchup'] as bool?) ?? false,
      supportsTimeshift: (data['capTimeshift'] as bool?) ?? false,
      supportsSubtitles: (data['capSubtitles'] as bool?) ?? false,
      supportsAudioTracks: (data['capAudioTracks'] as bool?) ?? false,
    );

    return ProviderSession(
      providerId: model.providerId,
      providerType: MediaSourceType.values[model.providerTypeIndex],
      sessionId: model.sessionId,
      cookies: _decryptJson(data['cookies'] as String?),
      headers: _decryptJson(data['headers'] as String?),
      bearerToken: _decryptOptional(data['bearerToken'] as String?),
      macAddress: _decryptOptional(data['macAddress'] as String?),
      deviceId: data['deviceId'] as String?,
      portalToken: _decryptOptional(data['portalToken'] as String?),
      username: _decryptOptional(data['username'] as String?),
      password: _decryptOptional(data['password'] as String?),
      expiresAt: expiresAt,
      userAgent: data['userAgent'] as String?,
      referer: data['referer'] as String?,
      origin: data['origin'] as String?,
      timeout: Duration(milliseconds: (data['timeoutMs'] as int?) ?? 15000),
      retryPolicy: retryPolicy,
      capabilities: capabilities,
      baseUrl: data['baseUrl'] as String?,
    );
  }

  String _encryptJson(Map<String, String> map) {
    if (map.isEmpty) return '';
    return _encryption.encrypt(jsonEncode(map));
  }

  Map<String, String> _decryptJson(String? cipher) {
    if (cipher == null || cipher.isEmpty) return const {};
    try {
      final decoded = jsonDecode(_encryption.decrypt(cipher));
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }
    } catch (_) {
      // Corrupt entry — treat as empty.
    }
    return const {};
  }

  String? _decryptOptional(String? cipher) {
    if (cipher == null || cipher.isEmpty) return null;
    try {
      return _encryption.decrypt(cipher);
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseDate(String? iso) {
    if (iso == null) return null;
    return DateTime.tryParse(iso);
  }

  String? _safe(String? value) => value == null || value.isEmpty ? null : value;
}
