import 'package:stream_hub/core/media/player/player_settings.dart';

class PlayerSettingsService {
  PlayerSettings _settings;

  PlayerSettingsService({PlayerSettings? settings})
      : _settings = settings ?? const PlayerSettings();

  PlayerSettings get settings => _settings;

  void update(PlayerSettings settings) {
    _settings = settings;
  }

  Future<void> resetToDefaults() async {
    _settings = const PlayerSettings();
  }
}
