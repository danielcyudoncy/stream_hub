import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/models/m3u_models.dart';
import 'package:stream_hub/data/services/free_tv_catalog_builder.dart';
import 'package:stream_hub/data/services/free_tv_m3u_normalizer.dart';
import 'package:stream_hub/data/services/free_tv_service.dart';
import 'package:stream_hub/data/sources/free_tv_sources.dart';

/// Fake HttpClient that returns pre-baked M3U text (UTF-8) per URL so the
/// catalog builder can run its real fetch → parse → normalize pipeline without
/// touching the network. A `null` body yields an HTTP 404.
class _FakeHttpClient implements HttpClient {
  final Map<String, String?> responses;

  _FakeHttpClient(this.responses);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _FakeHttpClientRequest(url, responses[url.toString()]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  final Uri uri;
  final String? body;
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  _FakeHttpClientRequest(this.uri, this.body);

  @override
  Future<HttpClientResponse> close() async {
    if (body == null) {
      return _FakeHttpClientResponse(404);
    }
    return _FakeHttpClientResponse(HttpStatus.ok, body: body);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  final int status;
  final String? body;

  _FakeHttpClientResponse(this.status, {this.body});

  @override
  int get statusCode => status;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(utf8.encode(body ?? '')).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _m3uHeader = '#EXTM3U\n';

String _entry({
  required String name,
  required String tvgId,
  String? country,
  String group = 'News;Public',
  String url = 'https://cdn.example.com/live.m3u8',
  String? logo,
}) {
  final attrs = <String>[
    if (tvgId.isNotEmpty) 'tvg-id="$tvgId"',
    if (country != null) 'country="$country"',
    'group-title="$group"',
    if (logo != null) 'tvg-logo="$logo"',
  ];
  return '#EXTINF:-1,${attrs.join(' ')},$name\n$url\n';
}

void main() {
  group('FreeTvService M3U pipeline', () {
    test('normalizer derives identity, country, category, and cleans names',
        () {
      final normalizer = FreeTvM3uNormalizer();
      final m3u = const M3UChannel(
        id: 'm3u-1',
        title: 'BBC News (1080p)',
        tvgId: 'BBCNews.GB@SD',
        group: 'News;Public',
        language: 'eng',
        logo: 'https://logo.com/bbc.png',
        streamUrl: 'https://bbc.stream/live.m3u8',
      );
      final ch = normalizer.toChannel(m3u);
      expect(ch, isNotNull);
      expect(ch!.id, 'BBCNews');
      expect(ch.countryCode, 'GB');
      expect(ch.country, 'United Kingdom');
      expect(ch.region, 'Europe');
      expect(ch.name, 'BBC News');
      expect(ch.categories, containsAll(['News', 'Public']));
      expect(ch.streamUrls.single, 'https://bbc.stream/live.m3u8');
    });

    test('builds a unified deduplicated catalog across multiple sources', () async {
      final indianGlobal = _m3uHeader +
          _entry(
            name: 'Times Now HD',
            tvgId: 'TimesNow.IN@HD',
            group: 'News',
            url: 'https://timesnow.stream/live.m3u8',
          );
      final ngGlobal = _m3uHeader +
          _entry(
            name: 'Channels TV',
            tvgId: 'ChannelsTV.NG@SD',
            country: 'NG',
            group: 'News',
            url: 'https://channelstv.stream/live.m3u8',
          );
      final ngCountry = _m3uHeader +
          _entry(
            name: 'Channels TV HD',
            tvgId: 'ChannelsTV.NG@HD',
            country: 'NG',
            group: 'News;Local',
            url: 'https://channelstv-hd.stream/live.m3u8',
          );

      final client = _FakeHttpClient({
        FreeTvSources.global.url: indianGlobal + ngGlobal,
        FreeTvSources.nigeria.url: ngCountry,
      });

      final builder = FreeTvCatalogBuilder(
        httpClient: client,
      );

      final result = await builder.build(sources: [
        FreeTvSources.global,
        FreeTvSources.nigeria,
      ]);

      // Channels TV appears in both sources (SD + HD) with different URLs. It
      // must be merged into ONE channel (stable id `ChannelsTV`) with both
      // streams deduplicated.
      final channelsTv = result.allValid
          .where((c) => c.id == 'ChannelsTV')
          .toList();
      expect(channelsTv.length, 1);
      expect(channelsTv.single.countryCode, 'NG');
      expect(channelsTv.single.streamUrls.length, 2);
      expect(
        channelsTv.single.streamUrls,
        containsAll([
          'https://channelstv.stream/live.m3u8',
          'https://channelstv-hd.stream/live.m3u8',
        ]),
      );
      // Categories unioned across sources.
      expect(channelsTv.single.categories, containsAll(['News', 'Local']));

      // Both channels survive in the unified catalog.
      expect(result.allValid.length, 2);
      expect(
        result.allValid.map((c) => c.id),
        containsAll(['ChannelsTV', 'TimesNow']),
      );
    });

    test('filters out NSFW, invalid-URL, and junk-named entries', () async {
      final global = _m3uHeader +
          _entry(
            name: 'News OK',
            tvgId: 'NewsOK.US@HD',
            group: 'News',
            url: 'https://ok.stream/live.m3u8',
          ) +
          // Invalid URL scheme
          _entry(
            name: 'Invalid Url',
            tvgId: 'Invalid.US@SD',
            group: 'News',
            url: 'ftp://bad.example/live',
          ) +
          // Junk/test name
          _entry(
            name: 'Test Channel',
            tvgId: 'TestChannel.US@SD',
            group: 'News',
            url: 'https://test.stream/live.m3u8',
          );

      final client = _FakeHttpClient({
        FreeTvSources.global.url: global,
      });

      final builder = FreeTvCatalogBuilder(httpClient: client);
      final result = await builder.build(sources: [FreeTvSources.global]);

      final ids = result.allValid.map((c) => c.id).toList();
      expect(ids, contains('NewsOK'));
      expect(ids, isNot(contains('Invalid')));
      expect(ids, isNot(contains('TestChannel')));
    });

    test('assigns recommended tier to rich, preferred-category channels',
        () async {
      final global = _m3uHeader +
          _entry(
            name: 'Documentary Channel',
            tvgId: 'DocCh.DE@HD',
            group: 'Documentary',
            country: 'DE',
            logo: 'https://logo.com/doc.png',
            url: 'https://doc.stream/live1.m3u8',
          ) +
          _entry(
            name: 'Minimal Channel 2',
            tvgId: 'MinCh.PL@SD',
            group: 'ObscureGroup',
            country: 'PL',
            url: 'https://min.stream/live.m3u8',
          );

      final client = _FakeHttpClient({
        FreeTvSources.global.url: global,
      });

      final builder = FreeTvCatalogBuilder(httpClient: client);
      final result = await builder.build(sources: [FreeTvSources.global]);

      final docCh = result.allValid.firstWhere((c) => c.id == 'DocCh');
      expect(docCh.qualityTier, FreeTvQualityTier.recommended);
      expect(docCh.qualityScore, greaterThanOrEqualTo(55));

      final minCh = result.allValid.firstWhere((c) => c.id == 'MinCh');
      expect(minCh.qualityTier, FreeTvQualityTier.valid);

      // Recommended only contains the curated tier.
      expect(result.recommended.map((c) => c.id), contains('DocCh'));
    });

    test('isolates a failing source without dropping the rest', () async {
      final good = _m3uHeader +
          _entry(
            name: 'UK News',
            tvgId: 'UKNews.UK@HD',
            group: 'News',
            url: 'https://uk.stream/live.m3u8',
          );

      // uk source will 404, global will succeed.
      final client = _FakeHttpClient({
        FreeTvSources.global.url: good,
        FreeTvSources.unitedKingdom.url: null,
      });

      final builder = FreeTvCatalogBuilder(httpClient: client);
      final result = await builder.build(sources: [
        FreeTvSources.global,
        FreeTvSources.unitedKingdom,
      ]);

      expect(result.allValid.map((c) => c.id), contains('UKNews'));
      final ukFetch = result.diagnostics.sources
          .firstWhere((s) => s.source.id == 'united_kingdom');
      expect(ukFetch.succeeded, isFalse);
      expect(ukFetch.error, isNotNull);
    });

    test('FreeTvService exposes curated recommended subset', () async {
      final global = _m3uHeader +
          _entry(
            name: 'Big News',
            tvgId: 'BigNews.US@HD',
            group: 'News',
            country: 'US',
            logo: 'https://logo.com/big.png',
            url: 'https://big.stream/live.m3u8',
          );

      final client = _FakeHttpClient({
        FreeTvSources.global.url: global,
      });

      final service = FreeTvService(
        builder: FreeTvCatalogBuilder(httpClient: client),
      );
      final catalog = await service.fetchCatalog();
      expect(catalog.length, 1);
      expect(catalog.single.id, 'BigNews');
      expect(catalog.single.qualityTier, FreeTvQualityTier.recommended);

      final recommended = await service.fetchRecommended();
      expect(recommended.map((c) => c.id), contains('BigNews'));
    });
  });
}
