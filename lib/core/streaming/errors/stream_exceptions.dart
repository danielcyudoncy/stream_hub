import 'package:stream_hub/core/errors/exceptions.dart';

/// Base class for all Stream Engine failures.
class StreamEngineException extends ApplicationException {
  const StreamEngineException({
    super.message = 'Stream engine error.',
    super.code = 'STREAM_ENGINE_ERROR',
    super.originalError,
  });
}

/// Thrown when a stream could not be resolved.
class StreamResolutionException extends StreamEngineException {
  const StreamResolutionException({
    super.message = 'Unable to resolve stream.',
    super.code = 'STREAM_RESOLUTION_ERROR',
    super.originalError,
  });
}

/// Thrown when a panel does not expose season/episode data for a series
/// (e.g. `get_series_info` is not implemented and returns HTTP 404).
///
/// This is a provider limitation rather than a request failure, so the UI can
/// degrade gracefully (show a friendly message) instead of retrying forever.
class StreamSeriesInfoUnavailableException extends StreamEngineException {
  const StreamSeriesInfoUnavailableException({
    super.message = 'This provider does not expose an episode list.',
    super.code = 'STREAM_SERIES_INFO_UNAVAILABLE',
    super.originalError,
  });
}

/// Thrown when a stream fails validation.
class StreamValidationException extends StreamEngineException {
  const StreamValidationException({
    super.message = 'Stream validation failed.',
    super.code = 'STREAM_VALIDATION_ERROR',
    super.originalError,
  });
}

/// Thrown when a provider or stream session has expired.
class StreamSessionExpiredException extends StreamEngineException {
  const StreamSessionExpiredException({
    super.message =
        'The stream session has expired. Please refresh and try again.',
    super.code = 'STREAM_SESSION_EXPIRED',
    super.originalError,
  });
}

/// Thrown when authentication failed (HTTP 401 / 403 or an invalid token).
class StreamAuthException extends StreamEngineException {
  const StreamAuthException({
    super.message = 'Authentication failed. Please verify your credentials.',
    super.code = 'STREAM_AUTH_FAILED',
    super.originalError,
  });
}

/// Thrown when the stream could not be found (HTTP 404).
class StreamNotFoundException extends StreamEngineException {
  const StreamNotFoundException({
    super.message = 'The stream was not found (404).',
    super.code = 'STREAM_NOT_FOUND',
    super.originalError,
  });
}

/// Thrown when a request timed out.
class StreamTimeoutException extends StreamEngineException {
  const StreamTimeoutException({
    super.message = 'The stream request timed out.',
    super.code = 'STREAM_TIMEOUT',
    super.originalError,
  });
}

/// Thrown when redirect handling detects a loop.
class StreamRedirectLoopException extends StreamEngineException {
  const StreamRedirectLoopException({
    super.message = 'The stream URL contains a redirect loop.',
    super.code = 'STREAM_REDIRECT_LOOP',
    super.originalError,
  });
}

/// Thrown when a provider session is invalid or missing.
class StreamInvalidSessionException extends StreamEngineException {
  const StreamInvalidSessionException({
    super.message = 'The provider session is invalid.',
    super.code = 'STREAM_INVALID_SESSION',
    super.originalError,
  });
}

/// Thrown when the stream URL is malformed.
class StreamMalformedUrlException extends StreamEngineException {
  const StreamMalformedUrlException({
    super.message = 'The stream URL is malformed.',
    super.code = 'STREAM_MALFORMED_URL',
    super.originalError,
  });
}

/// Thrown when the stream uses an unsupported protocol.
class StreamUnsupportedProtocolException extends StreamEngineException {
  const StreamUnsupportedProtocolException({
    super.message = 'The stream protocol is not supported.',
    super.code = 'STREAM_UNSUPPORTED_PROTOCOL',
    super.originalError,
  });
}

/// Thrown when a generic network error occurs during resolution or validation.
class StreamNetworkException extends StreamEngineException {
  const StreamNetworkException({
    super.message = 'A network error occurred while accessing the stream.',
    super.code = 'STREAM_NETWORK_ERROR',
    super.originalError,
  });
}

/// Thrown when an invalid header configuration was provided.
class StreamHeaderException extends StreamEngineException {
  const StreamHeaderException({
    super.message = 'Invalid stream headers provided.',
    super.code = 'STREAM_INVALID_HEADERS',
    super.originalError,
  });
}

/// Thrown when required cookies are missing.
class StreamCookieException extends StreamEngineException {
  const StreamCookieException({
    super.message = 'Required cookies are missing.',
    super.code = 'STREAM_MISSING_COOKIES',
    super.originalError,
  });
}

/// Thrown when a stream is not downloadable.
class StreamDownloadUnsupportedException extends StreamEngineException {
  const StreamDownloadUnsupportedException({
    super.message = 'This stream does not support downloading.',
    super.code = 'STREAM_DOWNLOAD_UNSUPPORTED',
    super.originalError,
  });
}
