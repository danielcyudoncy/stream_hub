package com.example.stream_hub

import androidx.annotation.OptIn
import androidx.media3.common.PlaybackException
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.HttpDataSource

/**
 * Shared diagnostics for the native ExoPlayer playback paths
 * ([NativePlayerActivity] and [ExoPlayerSurfaceView]).
 *
 * Provides error classification (network / HTTP / media / decoder / renderer),
 * credential-safe URL sanitization for log output, and consistent tagging so
 * every playback failure can be traced to its stage.
 *
 * Security: never log header values, cookies, tokens or passwords. URLs are
 * sanitized through [sanitizeUrl] before reaching logcat.
 */
@OptIn(markerClass = [UnstableApi::class])
object NativePlaybackDiagnostics {

    const val TAG_ACTIVITY = "NativePlayerActivity"
    const val TAG_SURFACE_VIEW = "ExoPlayerSurfaceView"

    /** Coarse failure categories used to decide the recovery strategy. */
    enum class ErrorCategory {
        /** Transient connectivity problem; safe for a controlled reconnect. */
        NETWORK,

        /** Stream server returned a 5xx; limited retry may help if transient. */
        SERVER,

        /** Authentication or authorization failure (401/403); never auto-retried. */
        AUTH,

        /** Missing resource (404/410); never auto-retried. */
        NOT_FOUND,

        /** Provider rate limiting (429); never auto-retried — retrying would worsen it. */
        RATE_LIMITED,

        /** Container / manifest parsing problem; never auto-retried. */
        MEDIA,

        /** MediaCodec initialization or runtime decode failure. */
        DECODER,

        /** Video/audio output pipeline failure (surface, frame release). */
        RENDERER,

        /** Anything else. */
        UNKNOWN,
        ;

        /** Stable identifier sent across the Flutter method channel. */
        val wireName: String
            get() = when (this) {
                NETWORK -> "network"
                SERVER -> "server"
                AUTH -> "auth"
                NOT_FOUND -> "notFound"
                RATE_LIMITED -> "rateLimited"
                MEDIA -> "media"
                DECODER -> "decoder"
                RENDERER -> "renderer"
                UNKNOWN -> "unknown"
            }
    }

    data class Classification(
        val category: ErrorCategory,
        val httpCode: Int?,
        val friendlyMessage: String,
    )

    /**
     * Classifies a [PlaybackException] into a [Classification] so recovery can
     * distinguish temporary faults (retry) from permanent ones (surface to UI).
     */
    fun classify(error: PlaybackException): Classification {
        val cause = error.cause
        val httpCode = (cause as? HttpDataSource.InvalidResponseCodeException)?.responseCode

        return when {
            httpCode == 401 || httpCode == 403 -> Classification(
                ErrorCategory.AUTH,
                httpCode,
                "Access denied (HTTP $httpCode): Stream link expired or invalid credentials.",
            )
            httpCode == 429 -> Classification(
                ErrorCategory.RATE_LIMITED,
                httpCode,
                "Rate limited (HTTP 429): Provider is limiting connections; try again later.",
            )
            httpCode == 408 -> Classification(
                ErrorCategory.NETWORK,
                httpCode,
                "Request timeout (HTTP 408): Server was too slow to respond.",
            )
            httpCode == 404 || httpCode == 410 -> Classification(
                ErrorCategory.NOT_FOUND,
                httpCode,
                "Stream not found (HTTP $httpCode): Channel stream may be offline.",
            )
            httpCode != null && httpCode >= 500 -> Classification(
                ErrorCategory.SERVER,
                httpCode,
                "Server error (HTTP $httpCode): Stream unavailable or connection limit exceeded.",
            )
            else -> when (error.errorCode) {
                PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED,
                PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT ->
                    Classification(
                        ErrorCategory.NETWORK,
                        null,
                        "Network error: Unable to connect to stream server.",
                    )
                PlaybackException.ERROR_CODE_BEHIND_LIVE_WINDOW ->
                    Classification(
                        ErrorCategory.NETWORK,
                        null,
                        "Live stream window moved; resynchronizing.",
                    )
                PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS ->
                    Classification(
                        ErrorCategory.SERVER,
                        null,
                        "Server error: Stream unavailable or connection limit exceeded.",
                    )
                PlaybackException.ERROR_CODE_IO_FILE_NOT_FOUND ->
                    Classification(
                        ErrorCategory.NOT_FOUND,
                        null,
                        "Stream file not found on server.",
                    )
                PlaybackException.ERROR_CODE_PARSING_CONTAINER_MALFORMED,
                PlaybackException.ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED,
                PlaybackException.ERROR_CODE_PARSING_MANIFEST_MALFORMED,
                PlaybackException.ERROR_CODE_PARSING_MANIFEST_UNSUPPORTED ->
                    Classification(
                        ErrorCategory.MEDIA,
                        null,
                        "Stream format unsupported or malformed.",
                    )
                PlaybackException.ERROR_CODE_DECODER_INIT_FAILED,
                PlaybackException.ERROR_CODE_DECODER_QUERY_FAILED,
                PlaybackException.ERROR_CODE_DECODING_FAILED,
                PlaybackException.ERROR_CODE_DECODING_FORMAT_EXCEEDS_CAPABILITIES,
                PlaybackException.ERROR_CODE_DECODING_FORMAT_UNSUPPORTED ->
                    Classification(
                        ErrorCategory.DECODER,
                        null,
                        "Video decoder failed to initialize or decode this stream.",
                    )
                PlaybackException.ERROR_CODE_VIDEO_FRAME_PROCESSING_FAILED,
                PlaybackException.ERROR_CODE_AUDIO_TRACK_INIT_FAILED,
                PlaybackException.ERROR_CODE_AUDIO_TRACK_WRITE_FAILED ->
                    Classification(
                        ErrorCategory.RENDERER,
                        null,
                        "Audio/video output failed on this device.",
                    )
                else -> Classification(
                    ErrorCategory.UNKNOWN,
                    httpCode,
                    "${error.errorCodeName}: ${error.message}",
                )
            }
        }
    }

    private val credentialQueryKeys =
        setOf(
            "password", "pass", "pwd", "username", "user", "token",
            "auth", "key", "secret", "session", "sessionid", "api_key",
        )

    /**
     * Returns a copy of [url] safe for logging: userinfo and fragment removed,
     * query parameters whose names look credential-bearing masked.
     */
    fun sanitizeUrl(url: String?): String {
        if (url.isNullOrBlank()) return ""
        return try {
            val juri = java.net.URI(url)
            val scheme = juri.scheme ?: return "(url omitted)"
            var authority = juri.rawAuthority
            if (authority != null && authority.contains('@')) {
                // Drop the userinfo component (user:password@host).
                authority = authority.substring(authority.lastIndexOf('@') + 1)
            }
            val sanitizedQuery = juri.rawQuery
                ?.split("&")
                ?.filter { it.isNotBlank() }
                ?.joinToString("&") { pair ->
                    val eq = pair.indexOf('=')
                    if (eq < 0) {
                        pair
                    } else {
                        val key = pair.substring(0, eq)
                        if (key.lowercase() in credentialQueryKeys) "$key=***" else pair
                    }
                }
            buildString {
                append(scheme).append("://")
                if (!authority.isNullOrEmpty()) append(authority)
                if (!juri.rawPath.isNullOrEmpty()) append(juri.rawPath)
                if (!sanitizedQuery.isNullOrEmpty()) append('?').append(sanitizedQuery)
            }
        } catch (_: Throwable) {
            "(url omitted)"
        }
    }

    /** Header names only — values may contain credentials and are never logged. */
    fun describeHeaders(headers: Map<String, String>): String {
        if (headers.isEmpty()) return "none"
        return headers.keys.joinToString(",")
    }
}
