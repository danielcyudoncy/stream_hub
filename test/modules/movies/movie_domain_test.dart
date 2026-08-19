import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/cast_member.dart';
import 'package:stream_hub/data/models/media_item.dart';

void main() {
  group('CastMember Model', () {
    test('parses from simple string with name only', () {
      final cast = CastMember.fromString('Leonardo DiCaprio');
      expect(cast.name, 'Leonardo DiCaprio');
      expect(cast.character, isNull);
      expect(cast.profileUrl, isNull);
    });

    test('parses from string with character name in parentheses or as', () {
      final cast1 = CastMember.fromString('Keanu Reeves (Neo)');
      expect(cast1.name, 'Keanu Reeves');
      expect(cast1.character, 'Neo');

      final cast2 = CastMember.fromString('Laurence Fishburne as Morpheus');
      expect(cast2.name, 'Laurence Fishburne');
      expect(cast2.character, 'Morpheus');
    });

    test('parses from map with various key names', () {
      final cast = CastMember.fromMap({
        'name': 'Christian Bale',
        'character': 'Bruce Wayne / Batman',
        'profile_path': 'https://image.tmdb.org/t/p/w185/bale.jpg',
      });
      expect(cast.name, 'Christian Bale');
      expect(cast.character, 'Bruce Wayne / Batman');
      expect(cast.profileUrl, 'https://image.tmdb.org/t/p/w185/bale.jpg');
    });

    test('serializes to Map correctly', () {
      const cast = CastMember(
        name: 'Tom Hanks',
        character: 'Forrest Gump',
        profileUrl: 'http://example.com/hanks.jpg',
      );
      final map = cast.toMap();
      expect(map['name'], 'Tom Hanks');
      expect(map['character'], 'Forrest Gump');
      expect(map['profileUrl'], 'http://example.com/hanks.jpg');
    });
  });

  group('MediaItemVodExtensions', () {
    test('extracts releaseYear from release_date or year', () {
      final item1 = MediaItem(
        id: 'm1',
        providerId: 'prov-1',
        title: 'Inception',
        mediaType: MediaType.movie,
        providerType: MediaSourceType.xtream,
        metadata: {'release_date': '2010-07-16'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(item1.releaseYear, 2010);

      final item2 = MediaItem(
        id: 'm2',
        providerId: 'prov-1',
        title: 'Interstellar',
        mediaType: MediaType.movie,
        providerType: MediaSourceType.xtream,
        metadata: {'year': 2014},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(item2.releaseYear, 2014);
    });

    test('formats duration into hours and minutes', () {
      final item1 = MediaItem(
        id: 'm1',
        providerId: 'prov-1',
        title: 'Movie 1',
        mediaType: MediaType.movie,
        providerType: MediaSourceType.xtream,
        metadata: {'duration': '148'}, // minutes
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(item1.durationMinutes, 148);
      expect(item1.formattedDuration, '2h 28m');

      final item2 = MediaItem(
        id: 'm2',
        providerId: 'prov-1',
        title: 'Movie 2',
        mediaType: MediaType.movie,
        providerType: MediaSourceType.xtream,
        metadata: {'duration_secs': 5400}, // 90 min
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(item2.durationMinutes, 90);
      expect(item2.formattedDuration, '1h 30m');

      final item3 = MediaItem(
        id: 'm3',
        providerId: 'prov-1',
        title: 'Short Movie',
        mediaType: MediaType.movie,
        providerType: MediaSourceType.xtream,
        metadata: {'duration': 45},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(item3.durationMinutes, 45);
      expect(item3.formattedDuration, '45m');
    });

    test('extracts director, originalTitle, trailerUrl, formattedRating', () {
      final item = MediaItem(
        id: 'm1',
        providerId: 'prov-1',
        title: 'Parasite',
        rating: 8.56,
        mediaType: MediaType.movie,
        providerType: MediaSourceType.xtream,
        metadata: {
          'director': 'Bong Joon-ho',
          'original_title': 'Gisaengchung',
          'youtube_trailer': 'isOGD_7hNIY',
          'country': 'South Korea',
          'language': 'Korean',
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(item.director, 'Bong Joon-ho');
      expect(item.originalTitle, 'Gisaengchung');
      expect(item.trailerUrl, 'isOGD_7hNIY');
      expect(item.resolvedCountry, 'South Korea');
      expect(item.resolvedLanguage, 'Korean');
      expect(item.formattedRating, '8.6');
    });

    test('parses cast members list from string or map list', () {
      final item = MediaItem(
        id: 'm1',
        providerId: 'prov-1',
        title: 'Movie',
        mediaType: MediaType.movie,
        providerType: MediaSourceType.xtream,
        metadata: {
          'cast': 'Actor One, Actor Two as Villain, Actor Three (Hero)',
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final cast = item.castMembers;
      expect(cast.length, 3);
      expect(cast[0].name, 'Actor One');
      expect(cast[1].name, 'Actor Two');
      expect(cast[1].character, 'Villain');
      expect(cast[2].name, 'Actor Three');
      expect(cast[2].character, 'Hero');
    });
  });
}
