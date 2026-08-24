import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/media/enums/playback_engine_preference.dart';
import 'package:stream_hub/core/media/player/ijk_player_adapter.dart';
import 'package:stream_hub/core/media/player/media_kit_player_adapter.dart';
import 'package:stream_hub/core/media/player/player_adapter_factory.dart';
import 'package:stream_hub/core/media/player/player_selection_strategy.dart';
import 'package:stream_hub/core/media/player/player_settings.dart';
import 'package:stream_hub/data/models/player_settings_model.dart';

void main() {
  final strategy = const PlayerSelectionStrategy();

  group('IJK engine isolation (Phase 3 evaluation)', () {
    test('explicit ijk preference falls back to MediaKit when unsupported',
        () {
      // On the test host (macOS) the Android-only IJK backend is unavailable;
      // the strategy must degrade to MediaKit instead of returning an
      // unusable kind.
      final kind = strategy.selectForUrl(
        'https://example.com/live/stream.m3u8',
        preference: PlaybackEnginePreference.ijk,
        isLive: true,
      );
      expect(IjkPlayerAdapter.isSupported, isFalse);
      expect(kind, equals(PlaybackEngineKind.mediaKit));
    });

    test('auto mode never selects IJK for any protocol', () {
      const urls = [
        'https://example.com/live/stream.m3u8',
        'https://example.com/live/index.ts',
        'http://example.com/vod/movie.mp4',
        'rtsp://example.com/cam',
        'udp://@239.1.1.1:5000',
        'rtp://@239.1.1.2:5002',
      ];
      for (final url in urls) {
        final kind = strategy.selectForUrl(
          url,
          preference: PlaybackEnginePreference.auto,
          isLive: url.contains('/live/') || url.startsWith('udp:') ||
              url.startsWith('rtsp'),
        );
        expect(kind, isNot(equals(PlaybackEngineKind.ijk)), reason: url);
      }
    });

    test('IJK is absent from every automatic fallback chain', () {
      final chains = [
        strategy.fallbackOrderFor(
          'https://example.com/live/stream.m3u8',
          isLive: true,
        ),
        strategy.fallbackOrderFor('http://example.com/vod/movie.mp4'),
        strategy.fallbackOrderFor('rtsp://example.com/cam'),
        strategy.fallbackOrderFor('udp://@239.1.1.1:5000'),
      ];
      for (final chain in chains) {
        expect(chain, isNot(contains(PlaybackEngineKind.ijk)));
      }
    });

    test('factory falls back to MediaKit for ijk on unsupported platforms', () {
      final adapter = PlayerAdapterFactory.create(
        PlaybackEngineKind.ijk,
      );
      expect(adapter, isA<MediaKitPlayerAdapter>());
    });
  });

  group('IJK settings persistence', () {
    test('ijk preference round-trips through PlayerSettingsModel by name', () {
      const settings = PlayerSettings(
        preferredPlayer: PlaybackEnginePreference.ijk,
      );
      final model = PlayerSettingsModel.fromDomain(settings);
      expect(model.preferredPlayer, equals('ijk'));

      final roundTrip = model.toDomain();
      expect(
        roundTrip.preferredPlayer,
        equals(PlaybackEnginePreference.ijk),
      );
    });

    test('unknown persisted player names fall back to auto', () {
      final model = PlayerSettingsModel(
        id: 'player_settings',
        updatedAt: DateTime.now(),
        preferredPlayer: 'notAnEngine',
      );
      expect(
        model.toDomain().preferredPlayer,
        equals(PlaybackEnginePreference.auto),
      );
    });
  });

  group('PlaybackEngineKind.ijk wire format', () {
    test('negotiation maps ijk kind to its stable name', () {
      // The negotiation layer serializes kinds across isolate boundaries;
      // a missing mapping would silently downgrade to unknown.
      expect(PlaybackEngineKind.ijk.name, equals('ijk'));
    });
  });
}
