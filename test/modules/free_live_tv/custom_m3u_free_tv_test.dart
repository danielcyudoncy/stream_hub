import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:stream_hub/data/models/dearbulut_dtos.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/remote/free_tv_m3u_remote_data_source.dart';
import 'package:stream_hub/data/remote/free_tv_remote_data_source.dart';
import 'package:stream_hub/data/repositories/free_tv_repository.dart';
import 'package:stream_hub/data/services/free_tv_catalog_builder.dart';
import 'package:stream_hub/data/services/free_tv_quality_service.dart';
import 'package:stream_hub/data/services/free_tv_service.dart';
import 'package:stream_hub/data/sources/free_tv_sources.dart';

class _EmptyDearbulutRemoteDataSource implements FreeTvRemoteDataSource {
  @override
  Future<List<DearbulutChannelDto>> fetchOnlineChannels({Duration? timeout}) async => const [];

  @override
  Future<List<DearbulutCountryDto>> fetchCountries({Duration? timeout}) async => const [];

  @override
  Future<List<DearbulutCategoryDto>> fetchCategories({Duration? timeout}) async => const [];

  @override
  Future<List<DearbulutChannelDto>> fetchChannelsByCountry(String countryCode, {Duration? timeout}) async => const [];

  @override
  Future<List<DearbulutChannelDto>> fetchChannelsByCategory(String categoryId, {Duration? timeout}) async => const [];
}

void main() {
  group('Custom M3U Free TV Integration Tests', () {
    late HttpServer server;
    late String fixtureContent;
    late Directory tempDir;

    setUpAll(() {
      fixtureContent = File('test/fixtures/sample_portal5458.m3u').readAsStringSync();
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('m3u_free_tv_test');
      Hive.init(tempDir.path);

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) {
        request.response.headers.contentType = ContentType.text;
        request.response.write(fixtureContent);
        request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('end-to-end: fetches M3U, normalizes into FreeTvChannel, scores quality', () async {
      final source = FreeTvSource(
        id: 'portal5458_test',
        name: 'Portal 5458 Test Source',
        url: 'http://${server.address.host}:${server.port}/get.php?username=spehar6&password=2934778645&type=m3u_plus',
        kind: FreeTvSourceKind.global,
      );

      final m3uDataSource = CustomM3uFreeTvRemoteDataSource(
        source: source,
        httpClient: HttpClient(),
      );

      final builder = FreeTvCatalogBuilder(
        remoteDataSource: _EmptyDearbulutRemoteDataSource(),
        m3uRemoteDataSource: m3uDataSource,
        quality: const FreeTvQualityService(englishOnly: false),
      );

      final result = await builder.build();

      expect(result.allValid.isNotEmpty, isTrue);
      // BBC One, CNN, ESPN, and Unknown Channel should all be normalized
      expect(result.allValid.length, 4);

      final bbc = result.allValid.firstWhere((c) => c.id == 'BBC');
      expect(bbc.name, 'BBC One');
      expect(bbc.categories, contains('News'));
      expect(bbc.countryCode, 'UK');
      expect(bbc.streams.isNotEmpty, isTrue);
      expect(bbc.streams.first.url, 'http://portal5458.com:8080/live/bbc.m3u8');
      expect(bbc.qualityScore, greaterThan(0));

      final espn = result.allValid.firstWhere((c) => c.id == 'ESPN');
      expect(espn.name, 'ESPN');
      expect(espn.categories, contains('Sports'));
      expect(espn.qualityTier, FreeTvQualityTier.recommended);

      // Diagnostics should reflect the custom M3U source contribution
      final m3uDiagnostic = result.diagnostics.sources.firstWhere(
        (s) => s.sourceName == 'portal5458_test',
      );
      expect(m3uDiagnostic.succeeded, isTrue);
      expect(m3uDiagnostic.rawRecords, 4);
    });

    test('toJson and fromJson round-trip perfectly preserves M3U-derived channels', () async {
      final source = FreeTvSource(
        id: 'portal5458_test',
        name: 'Portal 5458 Test Source',
        url: 'http://${server.address.host}:${server.port}/test.m3u',
        kind: FreeTvSourceKind.global,
      );

      final m3uDataSource = CustomM3uFreeTvRemoteDataSource(
        source: source,
        httpClient: HttpClient(),
      );

      final channels = await m3uDataSource.fetchOnlineChannels();
      expect(channels.isNotEmpty, isTrue);

      for (final original in channels) {
        final json = original.toJson();
        final reconstructed = FreeTvChannel.fromJson(json);

        expect(reconstructed.id, original.id);
        expect(reconstructed.name, original.name);
        expect(reconstructed.countryCode, original.countryCode);
        expect(reconstructed.categories, original.categories);
        expect(reconstructed.languages, original.languages);
        expect(reconstructed.streamUrls, original.streamUrls);
        expect(reconstructed.hasStream, isTrue);
        expect(reconstructed.primaryStreamUrl, original.primaryStreamUrl);
      }
    });

    test('Hive cache stores and retrieves M3U-derived channels correctly', () async {
      final source = FreeTvSource(
        id: 'portal5458_test',
        name: 'Portal 5458 Test Source',
        url: 'http://${server.address.host}:${server.port}/get.php?username=spehar6&password=2934778645&type=m3u_plus',
        kind: FreeTvSourceKind.global,
      );

      final m3uDataSource = CustomM3uFreeTvRemoteDataSource(
        source: source,
        httpClient: HttpClient(),
      );

      final service = FreeTvService(
        builder: FreeTvCatalogBuilder(
          remoteDataSource: _EmptyDearbulutRemoteDataSource(),
          m3uRemoteDataSource: m3uDataSource,
          quality: const FreeTvQualityService(englishOnly: false),
        ),
      );

      final repo = FreeTvRepository(service: service);

      // 1. Initial fetch: populates Hive cache
      final freshCatalog = await repo.getCatalog();
      expect(freshCatalog.length, 4);

      // 2. Favorite a channel
      final bbc = freshCatalog.firstWhere((c) => c.id == 'BBC');
      await repo.toggleFavorite(bbc.id);
      expect(await repo.isFavorite(bbc.id), isTrue);

      // 3. Second fetch: should load from Hive cache
      final cachedCatalog = await repo.getCatalog();
      expect(cachedCatalog.length, 4);

      final cachedBbc = cachedCatalog.firstWhere((c) => c.id == 'BBC');
      expect(cachedBbc.isFavorite, isTrue);
      expect(cachedBbc.name, 'BBC One');
      expect(cachedBbc.streamUrls.first, 'http://portal5458.com:8080/live/bbc.m3u8');
    });
  });
}
