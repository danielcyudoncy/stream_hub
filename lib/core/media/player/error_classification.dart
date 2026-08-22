/// Structured playback-error classification shared between the native
/// Android ExoPlayer backends and the Flutter [PlaybackEngine].
///
/// Mirrors `NativePlaybackDiagnostics.ErrorCategory` (Kotlin): the native
/// player classifies every `PlaybackException` before it crosses the method
/// channel, so recovery decisions (engine fallback vs surface error) never
/// depend on parsing human-readable message strings.
library;

/// Coarse failure categories for playback errors.
enum NativeErrorCategory {
  /// Transient connectivity problem (DNS, timeout, reset, refused).
  network,

  /// Stream server returned a 5xx.
  server,

  /// Authentication / authorization failure (401, 403).
  auth,

  /// Missing resource (404, 410).
  notFound,

  /// Provider rate limiting (429); retrying would worsen the situation.
  rateLimited,

  /// Malformed or unsupported container/manifest.
  media,

  /// MediaCodec initialization or runtime decode failure.
  decoder,

  /// Audio/video output pipeline failure (surface, no frames rendered).
  renderer,

  /// Anything else.
  unknown,
}

/// Parses the wire name emitted by the native diagnostics layer.
NativeErrorCategory? parseNativeErrorCategory(String? wireName) {
  if (wireName == null || wireName.isEmpty) return null;
  for (final value in NativeErrorCategory.values) {
    if (value.name == wireName) return value;
  }
  return null;
}

/// Implemented by [PlayerAdapter]s whose native backend reports a structured
/// error category alongside the human-readable message.
///
/// The PlaybackEngine consults the last reported category before attempting an
/// engine fallback, so a 403 (for example) surfaces directly instead of being
/// replayed through every other backend.
abstract mixin class StructuredErrorReporter {
  /// Category of the most recent structured error, or `null` when the active
  /// session has not produced a classified failure.
  NativeErrorCategory? get lastErrorCategory;

  /// HTTP status code attached to the most recent structured error, if any.
  int? get lastErrorHttpCode;

  /// Clears the stored classification; called when a new session loads so a
  /// past failure can never influence a later fallback decision.
  void clearLastError();
}

/// Pure fallback policy: decides whether swapping the playback backend can
/// plausibly resolve a failure of [category].
///
/// - `null` (no structured information available) preserves the legacy
///   behavior of trying the alternate engine.
/// - Auth, missing resources and rate limiting are properties of the *stream*
///   or the *provider*, not of the player: no backend can fix them, so the
///   error surfaces immediately instead of burning seconds on futile swaps.
/// - Network/server failures may respond to a different HTTP stack (VLC),
///   media/decoder failures to a different demuxer/decoder set, and renderer
///   failures to a different render path — all worth one fallback attempt.
bool shouldAttemptEngineFallback(NativeErrorCategory? category) {
  switch (category) {
    case NativeErrorCategory.auth:
    case NativeErrorCategory.notFound:
    case NativeErrorCategory.rateLimited:
      return false;
    case NativeErrorCategory.network:
    case NativeErrorCategory.server:
    case NativeErrorCategory.media:
    case NativeErrorCategory.decoder:
    case NativeErrorCategory.renderer:
    case NativeErrorCategory.unknown:
    case null:
      return true;
  }
}
