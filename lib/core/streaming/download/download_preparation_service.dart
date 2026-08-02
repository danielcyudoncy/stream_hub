import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/prepared_download.dart';
import 'package:stream_hub/core/streaming/network/cookie_manager.dart';
import 'package:stream_hub/core/streaming/network/header_engine.dart';

/// Prepares authenticated downloads from [PlayableSession]s.
///
/// Reuses the provider session, cookies, and headers produced by the Stream
/// Engine so downloads are always authenticated exactly like playback. The
/// Download Engine only receives [PreparedDownload]s.
class DownloadPreparationService {
  final CookieManager _cookieManager;
  final HeaderEngine _headerEngine;

  DownloadPreparationService({
    CookieManager? cookieManager,
    HeaderEngine? headerEngine,
  }) : _cookieManager = cookieManager ?? CookieManager(),
       _headerEngine = headerEngine ?? HeaderEngine();

  /// Validates download capability and assembles a [PreparedDownload].
  Future<PreparedDownload> prepare(PlayableSession session) async {
    if (!session.supportsDownload) {
      return PreparedDownload(
        session: session,
        canDownload: false,
        reason: 'Stream does not support downloading.',
      );
    }
    if (session.isExpired) {
      return PreparedDownload(
        session: session,
        canDownload: false,
        reason: 'Stream session has expired; refresh before downloading.',
      );
    }

    final extension = _extensionFor(session);
    return PreparedDownload(
      session: _ensureAuthenticated(session),
      canDownload: true,
      suggestedFileName: _suggestedFileName(session),
      fileExtension: extension,
    );
  }

  /// Ensures the session carries the same cookies/headers a live request would.
  PlayableSession _ensureAuthenticated(PlayableSession session) {
    final cookies = session.cookies.isNotEmpty
        ? session.cookies
        : _cookieManager.getCookies(session.providerId);

    if (cookies.isEmpty && session.headers.isNotEmpty) {
      return session;
    }
    if (cookies.isEmpty) return session;

    final cookieHeader = _headerEngine.buildHeaders(cookies: cookies)['Cookie'];
    if (cookieHeader == null) return session;

    return session.copyWith(
      cookies: cookies,
      headers: {...session.headers, 'Cookie': cookieHeader},
    );
  }

  String? _extensionFor(PlayableSession session) {
    switch (session.streamType) {
      case StreamType.mp4:
        return 'mp4';
      case StreamType.mkv:
        return 'mkv';
      case StreamType.hls:
      case StreamType.httpLive:
      case StreamType.httpsLive:
        return 'm3u8';
      case StreamType.dash:
        return 'mpd';
      case StreamType.mpegTs:
        return 'ts';
      default:
        return null;
    }
  }

  String? _suggestedFileName(PlayableSession session) {
    final extension = _extensionFor(session);
    if (extension == null) return null;
    final title =
        (session.metadata['title'] as String?)
            ?.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
            .toLowerCase() ??
        session.mediaItemId;
    return '$title.$extension';
  }
}
