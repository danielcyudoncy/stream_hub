import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/player/error_classification.dart';

void main() {
  group('parseNativeErrorCategory', () {
    test('parses every wire name round-trip', () {
      for (final category in NativeErrorCategory.values) {
        expect(parseNativeErrorCategory(category.name), category);
      }
    });

    test('returns null for unknown, empty, or missing values', () {
      expect(parseNativeErrorCategory('bogus'), isNull);
      expect(parseNativeErrorCategory(''), isNull);
      expect(parseNativeErrorCategory(null), isNull);
    });
  });

  group('shouldAttemptEngineFallback', () {
    test('falls back when no structured category is available', () {
      // Preserves the legacy behavior for backends without classification.
      expect(shouldAttemptEngineFallback(null), isTrue);
    });

    test('never falls back for auth failures', () {
      // An HTTP 403 fails identically under every engine; swapping players
      // cannot resolve it.
      expect(shouldAttemptEngineFallback(NativeErrorCategory.auth), isFalse);
    });

    test('never falls back for missing resources', () {
      expect(
        shouldAttemptEngineFallback(NativeErrorCategory.notFound),
        isFalse,
      );
    });

    test('never falls back for provider rate limiting', () {
      // Retrying a 429 through more engines worsens provider throttling.
      expect(
        shouldAttemptEngineFallback(NativeErrorCategory.rateLimited),
        isFalse,
      );
    });

    test('falls back for categories a different engine may fix', () {
      const fallbackCapable = <NativeErrorCategory>[
        NativeErrorCategory.network,
        NativeErrorCategory.server,
        NativeErrorCategory.media,
        NativeErrorCategory.decoder,
        NativeErrorCategory.renderer,
        NativeErrorCategory.unknown,
      ];
      for (final category in fallbackCapable) {
        expect(
          shouldAttemptEngineFallback(category),
          isTrue,
          reason: '$category should allow an engine fallback',
        );
      }
    });
  });
}
