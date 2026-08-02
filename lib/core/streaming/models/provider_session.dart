import 'package:flutter/foundation.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/models/stream_capabilities.dart';
import 'package:stream_hub/core/streaming/models/stream_retry_policy.dart';

/// A provider-level session that represents the authenticated, provider-specific
/// context required to request streams from a single IPTV provider.
///
/// Every provider (M3U, Xtream, Stalker, Plex, Jellyfin, Emby, ...) must produce
/// a [ProviderSession] through its adapter before any stream can be resolved.
@immutable
class ProviderSession {
  final String providerId;
  final MediaSourceType providerType;
  final String sessionId;

  final Map<String, String> cookies;
  final Map<String, String> headers;
  final String? bearerToken;
  final String? macAddress;
  final String? deviceId;
  final String? portalToken;
  final String? username;
  final String? password;
  final DateTime? expiresAt;

  final String? userAgent;
  final String? referer;
  final String? origin;

  final Duration timeout;
  final RetryPolicy retryPolicy;
  final StreamCapabilities capabilities;

  /// Base URL of the provider server (playlist URL, Xtream server URL, portal
  /// URL, ...). Used to resolve relative stream URLs.
  final String? baseUrl;

  const ProviderSession({
    required this.providerId,
    required this.providerType,
    required this.sessionId,
    this.cookies = const {},
    this.headers = const {},
    this.bearerToken,
    this.macAddress,
    this.deviceId,
    this.portalToken,
    this.username,
    this.password,
    this.expiresAt,
    this.userAgent,
    this.referer,
    this.origin,
    this.timeout = const Duration(seconds: 15),
    this.retryPolicy = const RetryPolicy(),
    this.capabilities = const StreamCapabilities(),
    this.baseUrl,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get requiresAuth =>
      bearerToken != null ||
      username != null ||
      password != null ||
      portalToken != null ||
      macAddress != null;

  ProviderSession copyWith({
    String? providerId,
    MediaSourceType? providerType,
    String? sessionId,
    Map<String, String>? cookies,
    Map<String, String>? headers,
    String? bearerToken,
    String? macAddress,
    String? deviceId,
    String? portalToken,
    String? username,
    String? password,
    DateTime? expiresAt,
    String? userAgent,
    String? referer,
    String? origin,
    Duration? timeout,
    RetryPolicy? retryPolicy,
    StreamCapabilities? capabilities,
    String? baseUrl,
  }) {
    return ProviderSession(
      providerId: providerId ?? this.providerId,
      providerType: providerType ?? this.providerType,
      sessionId: sessionId ?? this.sessionId,
      cookies: cookies ?? this.cookies,
      headers: headers ?? this.headers,
      bearerToken: bearerToken ?? this.bearerToken,
      macAddress: macAddress ?? this.macAddress,
      deviceId: deviceId ?? this.deviceId,
      portalToken: portalToken ?? this.portalToken,
      username: username ?? this.username,
      password: password ?? this.password,
      expiresAt: expiresAt ?? this.expiresAt,
      userAgent: userAgent ?? this.userAgent,
      referer: referer ?? this.referer,
      origin: origin ?? this.origin,
      timeout: timeout ?? this.timeout,
      retryPolicy: retryPolicy ?? this.retryPolicy,
      capabilities: capabilities ?? this.capabilities,
      baseUrl: baseUrl ?? this.baseUrl,
    );
  }
}
