import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/player/player_settings.dart';
import 'package:stream_hub/data/models/player_settings_model.dart';

void main() {
  group('PlayerSettings and AspectRatio Tests', () {
    test('PlayerSettings defaults to 16:9 aspect ratio', () {
      const settings = PlayerSettings();
      expect(settings.defaultAspectRatio, equals(AspectRatioMode.ratio16x9));
    });

    test('PlayerSettingsModel defaults to ratio16x9 and maps toDomain correctly', () {
      final model = PlayerSettingsModel(
        id: 'player_settings',
        updatedAt: DateTime.now(),
      );
      expect(model.defaultAspectRatio, equals('ratio16x9'));

      final domain = model.toDomain();
      expect(domain.defaultAspectRatio, equals(AspectRatioMode.ratio16x9));
    });

    test('PlayerSettingsModel.fromDomain preserves custom aspect ratio', () {
      const settings = PlayerSettings(
        defaultAspectRatio: AspectRatioMode.ratio4x3,
      );
      final model = PlayerSettingsModel.fromDomain(settings);
      expect(model.defaultAspectRatio, equals('ratio4x3'));

      final roundTrip = model.toDomain();
      expect(roundTrip.defaultAspectRatio, equals(AspectRatioMode.ratio4x3));
    });
  });
}
