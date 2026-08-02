import 'package:flutter/foundation.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/models/stream_capabilities.dart';

/// The output of the [StreamResolver] before authentication, header injection,
/// normalization, and validation have been applied.
@immutable
class StreamResolution {
  final String url;
  final StreamType streamType;
  final String? mimeType;
  final DateTime? expiresAt;
  final StreamCapabilities capabilities;
  final Map<String, String> queryParameters;
  final List<String> backupUrls;
  final String? drmScheme;
  final String? drmLicenseUrl;
  final Map<String, dynamic> metadata;

  const StreamResolution({
    required this.url,
    required this.streamType,
    this.mimeType,
    this.expiresAt,
    this.capabilities = const StreamCapabilities(),
    this.queryParameters = const {},
    this.backupUrls = const [],
    this.drmScheme,
    this.drmLicenseUrl,
    this.metadata = const {},
  });

  bool get isDrmProtected => drmScheme != null;

  StreamResolution copyWith({
    String? url,
    StreamType? streamType,
    String? mimeType,
    DateTime? expiresAt,
    StreamCapabilities? capabilities,
    Map<String, String>? queryParameters,
    List<String>? backupUrls,
    String? drmScheme,
    String? drmLicenseUrl,
    Map<String, dynamic>? metadata,
  }) {
    return StreamResolution(
      url: url ?? this.url,
      streamType: streamType ?? this.streamType,
      mimeType: mimeType ?? this.mimeType,
      expiresAt: expiresAt ?? this.expiresAt,
      capabilities: capabilities ?? this.capabilities,
      queryParameters: queryParameters ?? this.queryParameters,
      backupUrls: backupUrls ?? this.backupUrls,
      drmScheme: drmScheme ?? this.drmScheme,
      drmLicenseUrl: drmLicenseUrl ?? this.drmLicenseUrl,
      metadata: metadata ?? this.metadata,
    );
  }
}
