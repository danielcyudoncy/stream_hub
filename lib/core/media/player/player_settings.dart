import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/enums/playback_engine_preference.dart';

class PlayerSettings {
  final PlayerQuality defaultQuality;
  final String preferredAudioLanguage;
  final String preferredSubtitleLanguage;
  final bool hardwareDecode;
  final int bufferSizeSeconds;
  final bool autoResume;
  final bool autoFullscreen;
  final PlaybackSpeed defaultSpeed;
  final AspectRatioMode defaultAspectRatio;
  final bool rememberPosition;
  final int skipForwardSeconds;
  final int skipBackwardSeconds;
  final bool enableSubtitlesByDefault;
  final bool enableGestures;
  final bool enableKeyboardShortcuts;
  final bool enableTvRemote;
  final PlaybackEnginePreference preferredPlayer;

  const PlayerSettings({
    this.defaultQuality = PlayerQuality.auto,
    this.preferredAudioLanguage = 'en',
    this.preferredSubtitleLanguage = 'en',
    this.hardwareDecode = true,
    this.bufferSizeSeconds = 30,
    this.autoResume = true,
    this.autoFullscreen = false,
    this.defaultSpeed = PlaybackSpeed.speed1_0,
    this.defaultAspectRatio = AspectRatioMode.ratio16x9,
    this.rememberPosition = true,
    this.skipForwardSeconds = 10,
    this.skipBackwardSeconds = 10,
    this.enableSubtitlesByDefault = true,
    this.enableGestures = true,
    this.enableKeyboardShortcuts = true,
    this.enableTvRemote = true,
    this.preferredPlayer = PlaybackEnginePreference.auto,
  });

  PlayerSettings copyWith({
    PlayerQuality? defaultQuality,
    String? preferredAudioLanguage,
    String? preferredSubtitleLanguage,
    bool? hardwareDecode,
    int? bufferSizeSeconds,
    bool? autoResume,
    bool? autoFullscreen,
    PlaybackSpeed? defaultSpeed,
    AspectRatioMode? defaultAspectRatio,
    bool? rememberPosition,
    int? skipForwardSeconds,
    int? skipBackwardSeconds,
    bool? enableSubtitlesByDefault,
    bool? enableGestures,
    bool? enableKeyboardShortcuts,
    bool? enableTvRemote,
    PlaybackEnginePreference? preferredPlayer,
  }) {
    return PlayerSettings(
      defaultQuality: defaultQuality ?? this.defaultQuality,
      preferredAudioLanguage: preferredAudioLanguage ?? this.preferredAudioLanguage,
      preferredSubtitleLanguage:
          preferredSubtitleLanguage ?? this.preferredSubtitleLanguage,
      hardwareDecode: hardwareDecode ?? this.hardwareDecode,
      bufferSizeSeconds: bufferSizeSeconds ?? this.bufferSizeSeconds,
      autoResume: autoResume ?? this.autoResume,
      autoFullscreen: autoFullscreen ?? this.autoFullscreen,
      defaultSpeed: defaultSpeed ?? this.defaultSpeed,
      defaultAspectRatio: defaultAspectRatio ?? this.defaultAspectRatio,
      rememberPosition: rememberPosition ?? this.rememberPosition,
      skipForwardSeconds: skipForwardSeconds ?? this.skipForwardSeconds,
      skipBackwardSeconds: skipBackwardSeconds ?? this.skipBackwardSeconds,
      enableSubtitlesByDefault:
          enableSubtitlesByDefault ?? this.enableSubtitlesByDefault,
      enableGestures: enableGestures ?? this.enableGestures,
      enableKeyboardShortcuts:
          enableKeyboardShortcuts ?? this.enableKeyboardShortcuts,
      enableTvRemote: enableTvRemote ?? this.enableTvRemote,
      preferredPlayer: preferredPlayer ?? this.preferredPlayer,
    );
  }
}
