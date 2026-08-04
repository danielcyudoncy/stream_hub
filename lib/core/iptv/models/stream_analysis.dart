import 'package:flutter/foundation.dart';

/// A resolution frame captured from an HLS/DASH variant.
@immutable
class StreamResolutionInfo {
  final int? width;
  final int? height;

  const StreamResolutionInfo({this.width, this.height});

  String get label {
    if (width == null || height == null) return 'Unknown';
    return '${width}x$height';
  }

  /// Short marketing label for the largest dimension (720p / 1080p / 4K...).
  String get displayLabel {
    final h = height;
    if (h == null) return 'Unknown';
    if (h >= 2160) return '4K';
    if (h >= 1440) return '1440p';
    if (h >= 1080) return '1080p';
    if (h >= 720) return '720p';
    if (h >= 576) return '576p';
    if (h >= 480) return '480p';
    return '${h}p';
  }
}

/// Detailed technical analysis of a stream: codec, container, resolution,
/// frame rate, bitrate, audio, language, and DRM. Produced by the
/// [StreamAnalyzer].
@immutable
class StreamAnalysis {
  final String? videoCodec;
  final String? container;
  final StreamResolutionInfo? resolution;
  final double? frameRate;
  final int? videoBitrate;
  final String? audioCodec;
  final int? audioChannels;
  final String? audioLanguage;
  final int? sampleRate;
  final String? drmScheme;

  /// Number of adaptive variants (HLS/DASH quality ladder).
  final int variantCount;

  /// Longest advertised variant bandwidth in bits/second.
  final int? maxBandwidth;

  /// Average `#EXTINF` segment duration for HLS streams.
  final double? segmentDurationSeconds;

  final List<String> notes;

  const StreamAnalysis({
    this.videoCodec,
    this.container,
    this.resolution,
    this.frameRate,
    this.videoBitrate,
    this.audioCodec,
    this.audioChannels,
    this.audioLanguage,
    this.sampleRate,
    this.drmScheme,
    this.variantCount = 0,
    this.maxBandwidth,
    this.segmentDurationSeconds,
    this.notes = const [],
  });

  bool get hasVideoInfo =>
      videoCodec != null || resolution != null || videoBitrate != null;

  bool get hasAudioInfo => audioCodec != null || audioChannels != null;

  bool get isDrmProtected => drmScheme != null && drmScheme!.isNotEmpty;

  String get summary {
    final parts = <String>[
      container ?? 'container unknown',
      resolution?.displayLabel ?? 'resolution unknown',
      videoCodec ?? 'codec unknown',
    ];
    if (maxBandwidth != null && maxBandwidth! > 0) {
      parts.add('${(maxBandwidth! / 1000000).toStringAsFixed(2)} Mbps');
    }
    return parts.join(' · ');
  }

  StreamAnalysis copyWith({
    String? videoCodec,
    String? container,
    StreamResolutionInfo? resolution,
    double? frameRate,
    int? videoBitrate,
    String? audioCodec,
    int? audioChannels,
    String? audioLanguage,
    int? sampleRate,
    String? drmScheme,
    int? variantCount,
    int? maxBandwidth,
    double? segmentDurationSeconds,
    List<String>? notes,
  }) {
    return StreamAnalysis(
      videoCodec: videoCodec ?? this.videoCodec,
      container: container ?? this.container,
      resolution: resolution ?? this.resolution,
      frameRate: frameRate ?? this.frameRate,
      videoBitrate: videoBitrate ?? this.videoBitrate,
      audioCodec: audioCodec ?? this.audioCodec,
      audioChannels: audioChannels ?? this.audioChannels,
      audioLanguage: audioLanguage ?? this.audioLanguage,
      sampleRate: sampleRate ?? this.sampleRate,
      drmScheme: drmScheme ?? this.drmScheme,
      variantCount: variantCount ?? this.variantCount,
      maxBandwidth: maxBandwidth ?? this.maxBandwidth,
      segmentDurationSeconds:
          segmentDurationSeconds ?? this.segmentDurationSeconds,
      notes: notes ?? this.notes,
    );
  }
}
