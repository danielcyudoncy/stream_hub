import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/data/services/free_tv_service.dart';

class _FakeHttpClient implements HttpClient {
  final Map<String, dynamic> responses;

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
  final dynamic responseData;
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  _FakeHttpClientRequest(this.uri, this.responseData);

  @override
  Future<HttpClientResponse> close() async {
    return _FakeHttpClientResponse(responseData);
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
  final dynamic data;

  _FakeHttpClientResponse(this.data);

  @override
  int get statusCode => HttpStatus.ok;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final jsonStr = json.encode(data);
    final bytes = utf8.encode(jsonStr);
    return Stream.value(bytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('FreeTvService Pipeline Tests', () {
    test('fetches, matches streams, excludes NSFW, and deduplicates streams',
        () async {
      final fakeResponses = {
        FreeTvService.kChannelsUrl: [
          {
            'id': 'ChannelsTV.ng',
            'name': 'Channels Television',
            'country': 'NG',
            'categories': ['news'],
            'languages': ['eng'],
            'is_nsfw': false,
            'logo': 'https://logo.com/channels.png',
          },
          {
            'id': 'NsfwChannel.xx',
            'name': 'NSFW Channel',
            'country': 'US',
            'is_nsfw': true,
          },
          {
            'id': 'OrphanChannel.uk',
            'name': 'Orphan Channel Without Stream',
            'country': 'UK',
            'is_nsfw': false,
          },
          {
            'id': '',
            'name': 'Malformed Channel Missing ID',
          },
        ],
        FreeTvService.kStreamsUrl: [
          {
            'channel': 'ChannelsTV.ng',
            'url': 'https://stream1.channelstv.com/live.m3u8',
          },
          {
            'channel': 'ChannelsTV.ng',
            'url': 'https://stream2.channelstv.com/backup.m3u8',
          },
          {
            'channel': 'ChannelsTV.ng',
            'url': 'https://stream1.channelstv.com/live.m3u8', // duplicate
          },
          {
            'channel': 'NsfwChannel.xx',
            'url': 'https://nsfw.stream/live.m3u8',
          },
          {
            'channel': 'NonExistentChannel.zz',
            'url': 'https://orphan.stream/live.m3u8',
          },
        ],
        FreeTvService.kCountriesUrl: [
          {'code': 'NG', 'name': 'Nigeria'},
          {'code': 'US', 'name': 'United States'},
          {'code': 'UK', 'name': 'United Kingdom'},
        ],
        FreeTvService.kCategoriesUrl: [
          {'id': 'news', 'name': 'News'},
        ],
      };

      final client = _FakeHttpClient(fakeResponses);
      final service = FreeTvService(httpClient: client);

      final catalog = await service.fetchCatalog();

      // Only ChannelsTV.ng should survive the pipeline:
      // - NsfwChannel is filtered out because is_nsfw == true
      // - OrphanChannel is filtered out because it has no streams
      // - Malformed channel is filtered out because ID is empty
      expect(catalog.length, 1);

      final channel = catalog.first;
      expect(channel.id, 'ChannelsTV.ng');
      expect(channel.name, 'Channels Television');
      expect(channel.country, 'Nigeria');
      expect(channel.countryCode, 'NG');
      // Streams should be deduplicated to 2 streams
      expect(channel.streamUrls.length, 2);
      expect(channel.streamUrls[0],
          'https://stream1.channelstv.com/live.m3u8');
      expect(channel.streamUrls[1],
          'https://stream2.channelstv.com/backup.m3u8');
    });
  });
}
