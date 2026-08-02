import 'package:flutter/foundation.dart';

/// Describes the playback features a resolved stream supports.
@immutable
class StreamCapabilities {
  final bool supportsSeeking;
  final bool supportsPause;
  final bool supportsRecording;
  final bool supportsDownload;
  final bool supportsCatchup;
  final bool supportsTimeshift;
  final bool supportsSubtitles;
  final bool supportsAudioTracks;
  final bool supportsQualitySelection;
  final bool supportsResume;

  const StreamCapabilities({
    this.supportsSeeking = false,
    this.supportsPause = true,
    this.supportsRecording = false,
    this.supportsDownload = false,
    this.supportsCatchup = false,
    this.supportsTimeshift = false,
    this.supportsSubtitles = false,
    this.supportsAudioTracks = false,
    this.supportsQualitySelection = false,
    this.supportsResume = true,
  });

  const StreamCapabilities.live()
    : this(
        supportsSeeking: false,
        supportsPause: true,
        supportsRecording: true,
        supportsDownload: false,
        supportsCatchup: false,
        supportsTimeshift: false,
      );

  const StreamCapabilities.vod()
    : this(
        supportsSeeking: true,
        supportsPause: true,
        supportsRecording: false,
        supportsDownload: true,
        supportsSubtitles: true,
        supportsAudioTracks: true,
        supportsQualitySelection: true,
        supportsResume: true,
      );

  StreamCapabilities copyWith({
    bool? supportsSeeking,
    bool? supportsPause,
    bool? supportsRecording,
    bool? supportsDownload,
    bool? supportsCatchup,
    bool? supportsTimeshift,
    bool? supportsSubtitles,
    bool? supportsAudioTracks,
    bool? supportsQualitySelection,
    bool? supportsResume,
  }) {
    return StreamCapabilities(
      supportsSeeking: supportsSeeking ?? this.supportsSeeking,
      supportsPause: supportsPause ?? this.supportsPause,
      supportsRecording: supportsRecording ?? this.supportsRecording,
      supportsDownload: supportsDownload ?? this.supportsDownload,
      supportsCatchup: supportsCatchup ?? this.supportsCatchup,
      supportsTimeshift: supportsTimeshift ?? this.supportsTimeshift,
      supportsSubtitles: supportsSubtitles ?? this.supportsSubtitles,
      supportsAudioTracks: supportsAudioTracks ?? this.supportsAudioTracks,
      supportsQualitySelection:
          supportsQualitySelection ?? this.supportsQualitySelection,
      supportsResume: supportsResume ?? this.supportsResume,
    );
  }
}
