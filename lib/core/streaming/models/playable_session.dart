import 'package:flutter/foundation.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/models/drm_information.dart';
import 'package:stream_hub/core/streaming/models/stream_retry_policy.dart';

/// The single object understood by the Playback Engine and the Download Engine.
///
/// A [PlayableSession] is an authenticated, validated, normalized stream that
/// is ready to be played or downloaded. No player or download engine should
/// ever receive a raw provider URL, provider model, or provider header set.
@immutable
class PlayableSession {
  final String sessionId;
  final String mediaItemId;
  final String providerId;
  final MediaSourceType providerType;

  final String streamUrl;
  final StreamType streamType;
  final String? mimeType;

  final Map<String, String> headers;
  final Map<String, String> cookies;
  final Map<String, String> queryParameters;
  final String? bearerToken;
  final String? referer;
  final String? origin;
  final String? userAgent;

  final DateTime? expiresAt;

  final bool supportsSeeking;
  final bool supportsPause;
  final bool supportsRecording;
  final bool supportsDownload;
  final bool supportsCatchup;
  final bool supportsTimeshift;
  final bool supportsSubtitles;
  final bool supportsAudioTracks;

  final DrmInformation? drmInformation;

  final Duration networkTimeout;
  final RetryPolicy retryPolicy;
  final Map<String, dynamic> metadata;

  const PlayableSession({
    required this.sessionId,
    required this.mediaItemId,
    required this.providerId,
    required this.providerType,
    required this.streamUrl,
    required this.streamType,
    this.mimeType,
    this.headers = const {},
    this.cookies = const {},
    this.queryParameters = const {},
    this.bearerToken,
    this.referer,
    this.origin,
    this.userAgent,
    this.expiresAt,
    this.supportsSeeking = false,
    this.supportsPause = true,
    this.supportsRecording = false,
    this.supportsDownload = false,
    this.supportsCatchup = false,
    this.supportsTimeshift = false,
    this.supportsSubtitles = false,
    this.supportsAudioTracks = false,
    this.drmInformation,
    this.networkTimeout = const Duration(seconds: 15),
    this.retryPolicy = const RetryPolicy(),
    this.metadata = const {},
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get requiresBearerToken => bearerToken != null;

  String get cacheKey => '$providerId:$mediaItemId';

  PlayableSession copyWith({
    String? sessionId,
    String? mediaItemId,
    String? providerId,
    MediaSourceType? providerType,
    String? streamUrl,
    StreamType? streamType,
    String? mimeType,
    Map<String, String>? headers,
    Map<String, String>? cookies,
    Map<String, String>? queryParameters,
    String? bearerToken,
    String? referer,
    String? origin,
    String? userAgent,
    DateTime? expiresAt,
    bool? supportsSeeking,
    bool? supportsPause,
    bool? supportsRecording,
    bool? supportsDownload,
    bool? supportsCatchup,
    bool? supportsTimeshift,
    bool? supportsSubtitles,
    bool? supportsAudioTracks,
    DrmInformation? drmInformation,
    Duration? networkTimeout,
    RetryPolicy? retryPolicy,
    Map<String, dynamic>? metadata,
  }) {
    return PlayableSession(
      sessionId: sessionId ?? this.sessionId,
      mediaItemId: mediaItemId ?? this.mediaItemId,
      providerId: providerId ?? this.providerId,
      providerType: providerType ?? this.providerType,
      streamUrl: streamUrl ?? this.streamUrl,
      streamType: streamType ?? this.streamType,
      mimeType: mimeType ?? this.mimeType,
      headers: headers ?? this.headers,
      cookies: cookies ?? this.cookies,
      queryParameters: queryParameters ?? this.queryParameters,
      bearerToken: bearerToken ?? this.bearerToken,
      referer: referer ?? this.referer,
      origin: origin ?? this.origin,
      userAgent: userAgent ?? this.userAgent,
      expiresAt: expiresAt ?? this.expiresAt,
      supportsSeeking: supportsSeeking ?? this.supportsSeeking,
      supportsPause: supportsPause ?? this.supportsPause,
      supportsRecording: supportsRecording ?? this.supportsRecording,
      supportsDownload: supportsDownload ?? this.supportsDownload,
      supportsCatchup: supportsCatchup ?? this.supportsCatchup,
      supportsTimeshift: supportsTimeshift ?? this.supportsTimeshift,
      supportsSubtitles: supportsSubtitles ?? this.supportsSubtitles,
      supportsAudioTracks: supportsAudioTracks ?? this.supportsAudioTracks,
      drmInformation: drmInformation ?? this.drmInformation,
      networkTimeout: networkTimeout ?? this.networkTimeout,
      retryPolicy: retryPolicy ?? this.retryPolicy,
      metadata: metadata ?? this.metadata,
    );
  }
}
