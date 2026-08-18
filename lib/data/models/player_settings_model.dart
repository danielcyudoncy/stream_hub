import 'package:hive/hive.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/enums/playback_engine_preference.dart';
import 'package:stream_hub/core/media/player/player_settings.dart';

part 'player_settings_model.g.dart';

@HiveType(typeId: 12)
class PlayerSettingsModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String defaultQuality;

  @HiveField(2)
  String preferredAudioLanguage;

  @HiveField(3)
  String preferredSubtitleLanguage;

  @HiveField(4)
  bool hardwareDecode;

  @HiveField(5)
  int bufferSizeSeconds;

  @HiveField(6)
  bool autoResume;

  @HiveField(7)
  bool autoFullscreen;

  @HiveField(8)
  double defaultSpeed;

  @HiveField(9)
  String defaultAspectRatio;

  @HiveField(10)
  bool rememberPosition;

  @HiveField(11)
  int skipForwardSeconds;

  @HiveField(12)
  int skipBackwardSeconds;

  @HiveField(13)
  bool enableSubtitlesByDefault;

  @HiveField(14)
  bool enableGestures;

  @HiveField(15)
  bool enableKeyboardShortcuts;

  @HiveField(16)
  bool enableTvRemote;

  @HiveField(17)
  final DateTime updatedAt;

  @HiveField(18)
  String preferredPlayer;

  PlayerSettingsModel({
    required this.id,
    this.defaultQuality = 'auto',
    this.preferredAudioLanguage = 'en',
    this.preferredSubtitleLanguage = 'en',
    this.hardwareDecode = true,
    this.bufferSizeSeconds = 30,
    this.autoResume = true,
    this.autoFullscreen = false,
    this.defaultSpeed = 1.0,
    this.defaultAspectRatio = 'ratio16x9',
    this.rememberPosition = true,
    this.skipForwardSeconds = 10,
    this.skipBackwardSeconds = 10,
    this.enableSubtitlesByDefault = true,
    this.enableGestures = true,
    this.enableKeyboardShortcuts = true,
    this.enableTvRemote = true,
    this.preferredPlayer = 'auto',
    required this.updatedAt,
  });

  PlayerSettings toDomain() {
    return PlayerSettings(
      defaultQuality: _parseQuality(defaultQuality),
      preferredAudioLanguage: preferredAudioLanguage,
      preferredSubtitleLanguage: preferredSubtitleLanguage,
      hardwareDecode: hardwareDecode,
      bufferSizeSeconds: bufferSizeSeconds,
      autoResume: autoResume,
      autoFullscreen: autoFullscreen,
      defaultSpeed: PlaybackSpeed.fromValue(defaultSpeed),
      defaultAspectRatio: AspectRatioMode.values.firstWhere(
        (a) => a.name == defaultAspectRatio,
        orElse: () => AspectRatioMode.ratio16x9,
      ),
      rememberPosition: rememberPosition,
      skipForwardSeconds: skipForwardSeconds,
      skipBackwardSeconds: skipBackwardSeconds,
      enableSubtitlesByDefault: enableSubtitlesByDefault,
      enableGestures: enableGestures,
      enableKeyboardShortcuts: enableKeyboardShortcuts,
      enableTvRemote: enableTvRemote,
      preferredPlayer: _parsePreferredPlayer(preferredPlayer),
    );
  }

  factory PlayerSettingsModel.fromDomain(PlayerSettings settings) {
    return PlayerSettingsModel(
      id: 'player_settings',
      defaultQuality: settings.defaultQuality.name,
      preferredAudioLanguage: settings.preferredAudioLanguage,
      preferredSubtitleLanguage: settings.preferredSubtitleLanguage,
      hardwareDecode: settings.hardwareDecode,
      bufferSizeSeconds: settings.bufferSizeSeconds,
      autoResume: settings.autoResume,
      autoFullscreen: settings.autoFullscreen,
      defaultSpeed: settings.defaultSpeed.value,
      defaultAspectRatio: settings.defaultAspectRatio.name,
      rememberPosition: settings.rememberPosition,
      skipForwardSeconds: settings.skipForwardSeconds,
      skipBackwardSeconds: settings.skipBackwardSeconds,
      enableSubtitlesByDefault: settings.enableSubtitlesByDefault,
      enableGestures: settings.enableGestures,
      enableKeyboardShortcuts: settings.enableKeyboardShortcuts,
      enableTvRemote: settings.enableTvRemote,
      preferredPlayer: settings.preferredPlayer.name,
      updatedAt: DateTime.now(),
    );
  }

  PlayerQuality _parseQuality(String value) {
    try {
      return PlayerQuality.values.firstWhere((q) => q.name == value);
    } catch (_) {
      return PlayerQuality.auto;
    }
  }

  PlaybackEnginePreference _parsePreferredPlayer(String value) {
    return PlaybackEnginePreference.values.firstWhere(
      (p) => p.name == value,
      orElse: () => PlaybackEnginePreference.auto,
    );
  }
}
