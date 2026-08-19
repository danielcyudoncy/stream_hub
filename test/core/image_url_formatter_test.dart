import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/utils/image_url_formatter.dart';
import 'package:stream_hub/data/models/media_item.dart';

void main() {
  group('ImageUrlFormatter', () {
    group('format', () {
      test('returns absolute HTTP URLs unchanged', () {
        expect(
          ImageUrlFormatter.format('http://cdn.example.com/poster.jpg'),
          'http://cdn.example.com/poster.jpg',
        );
      });

      test('returns absolute HTTPS URLs unchanged', () {
        expect(
          ImageUrlFormatter.format('https://cdn.example.com/poster.jpg'),
          'https://cdn.example.com/poster.jpg',
        );
      });

      test('converts protocol-relative URLs to HTTPS', () {
        expect(
          ImageUrlFormatter.format('//cdn.example.com/poster.jpg'),
          'https://cdn.example.com/poster.jpg',
        );
      });

      test('resolves explicit TMDB paths against TMDB', () {
        expect(
          ImageUrlFormatter.format('/t/p/w500/abc.jpg'),
          'https://image.tmdb.org/t/p/w500/abc.jpg',
        );
      });

      group('single-segment relative paths', () {
        test('resolves TMDB hash with leading slash against TMDB even with serverUrl', () {
          expect(
            ImageUrlFormatter.format('/7bWxSbN1Jq9Acql9B5D8v5Y9p3D.jpg', serverUrl: 'http://panel.com'),
            'https://image.tmdb.org/t/p/w500/7bWxSbN1Jq9Acql9B5D8v5Y9p3D.jpg',
          );
        });

        test('resolves non-hash filename against serverUrl when provided', () {
          expect(
            ImageUrlFormatter.format('/inception.jpg', serverUrl: 'http://panel.com'),
            'http://panel.com/inception.jpg',
          );
        });

        test('fall back to TMDB when no serverUrl is provided', () {
          expect(
            ImageUrlFormatter.format('/inception.jpg'),
            'https://image.tmdb.org/t/p/w500/inception.jpg',
          );
        });
      });

      group('multi-segment relative paths', () {
        test('resolve against serverUrl preserving subpath', () {
          expect(
            ImageUrlFormatter.format('/images/poster.jpg', serverUrl: 'http://panel.com/xtream'),
            'http://panel.com/xtream/images/poster.jpg',
          );
        });

        test('fall back to TMDB when no serverUrl is provided', () {
          expect(
            ImageUrlFormatter.format('/images/poster.jpg'),
            'https://image.tmdb.org/t/p/w500/images/poster.jpg',
          );
        });
      });

      group('bare filenames', () {
        test('bare TMDB hashes resolve to TMDB', () {
          expect(
            ImageUrlFormatter.format('7bWxSbN1Jq9Acql9B5D8v5Y9p3D.jpg', serverUrl: 'http://panel.com'),
            'https://image.tmdb.org/t/p/w500/7bWxSbN1Jq9Acql9B5D8v5Y9p3D.jpg',
          );
        });

        test('bare filenames with serverUrl resolve against serverUrl', () {
          expect(
            ImageUrlFormatter.format('abc123.jpg', serverUrl: 'http://panel.com'),
            'http://panel.com/abc123.jpg',
          );
        });
      });

      group('JSON array strings', () {
        test('decodes JSON array string containing TMDB path', () {
          expect(
            ImageUrlFormatter.format('["/7bWxSbN1Jq9Acql9B5D8v5Y9p3D.jpg"]', serverUrl: 'http://panel.com'),
            'https://image.tmdb.org/t/p/w500/7bWxSbN1Jq9Acql9B5D8v5Y9p3D.jpg',
          );
        });

        test('decodes JSON array string containing absolute URL', () {
          expect(
            ImageUrlFormatter.format('["http://cdn.example.com/poster.jpg"]'),
            'http://cdn.example.com/poster.jpg',
          );
        });
      });

      group('corrupted and embedded absolute URLs', () {
        test('extracts embedded absolute TMDB URL', () {
          expect(
            ImageUrlFormatter.format('http://panel.com:8080/https://image.tmdb.org/t/p/w500/abc.jpg'),
            'https://image.tmdb.org/t/p/w500/abc.jpg',
          );
        });

        test('extracts /t/p/ path from custom host', () {
          expect(
            ImageUrlFormatter.format('http://panel.com:8080/t/p/w500/abc.jpg'),
            'https://image.tmdb.org/t/p/w500/abc.jpg',
          );
        });

        test('preserves absolute URL on custom host', () {
          expect(
            ImageUrlFormatter.format('http://panel.com:8080/7bWxSbN1Jq9Acql9B5D8v5Y9p3D.jpg'),
            'http://panel.com:8080/7bWxSbN1Jq9Acql9B5D8v5Y9p3D.jpg',
          );
        });
      });

      group('with MediaItem metadata', () {
        test('uses metadata serverUrl for relative paths', () {
          final item = MediaItem(
            id: '1',
            providerId: 'p',
            providerType: MediaSourceType.xtream,
            mediaType: MediaType.movie,
            title: 'Test',
            metadata: {'serverUrl': 'http://panel.com/xtream'},
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          expect(
            ImageUrlFormatter.format('/movie.jpg', item: item),
            'http://panel.com/xtream/movie.jpg',
          );
        });
      });
    });

    group('extractFromMap', () {
      test('extracts TMDB stream_icon and resolves against TMDB', () {
        final result = ImageUrlFormatter.extractFromMap(
          {'stream_icon': '/7bWxSbN1Jq9Acql9B5D8v5Y9p3D.jpg'},
          serverUrl: 'http://panel.com',
        );
        expect(result, 'https://image.tmdb.org/t/p/w500/7bWxSbN1Jq9Acql9B5D8v5Y9p3D.jpg');
      });

      test('extracts stream_icon and resolves relative path against serverUrl', () {
        final result = ImageUrlFormatter.extractFromMap(
          {'stream_icon': '/inception.jpg'},
          serverUrl: 'http://panel.com',
        );
        expect(result, 'http://panel.com/inception.jpg');
      });

      test('extracts from nested info map when top level is empty', () {
        final result = ImageUrlFormatter.extractFromMap(
          {
            'stream_icon': '',
            'info': {
              'cover_big': 'https://image.tmdb.org/t/p/w500/7bWxSbN1Jq9Acql9B5D8v5Y9p3D.jpg',
            },
          },
          serverUrl: 'http://panel.com',
        );
        expect(result, 'https://image.tmdb.org/t/p/w500/7bWxSbN1Jq9Acql9B5D8v5Y9p3D.jpg');
      });

      test('falls back through multiple image keys', () {
        final result = ImageUrlFormatter.extractFromMap(
          {
            'cover_big': '',
            'cover': '/cover.jpg',
            'movie_image': '/movie.jpg',
          },
          serverUrl: 'http://panel.com',
        );
        expect(result, 'http://panel.com/cover.jpg');
      });
    });

    group('extractFromMediaItem', () {
      test('prefers direct poster property', () {
        final item = MediaItem(
          id: '1',
          providerId: 'p',
          providerType: MediaSourceType.xtream,
          mediaType: MediaType.movie,
          title: 'Test',
          poster: 'http://cdn.example.com/direct.jpg',
          metadata: {'stream_icon': '/meta.jpg', 'serverUrl': 'http://panel.com'},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(
          ImageUrlFormatter.extractFromMediaItem(item),
          'http://cdn.example.com/direct.jpg',
        );
      });

      test('falls back to metadata poster when direct is empty', () {
        final item = MediaItem(
          id: '1',
          providerId: 'p',
          providerType: MediaSourceType.xtream,
          mediaType: MediaType.movie,
          title: 'Test',
          metadata: {'stream_icon': '/meta.jpg', 'serverUrl': 'http://panel.com'},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(
          ImageUrlFormatter.extractFromMediaItem(item),
          'http://panel.com/meta.jpg',
        );
      });
    });
  });
}
