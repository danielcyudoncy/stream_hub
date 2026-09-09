import 'package:stream_hub/data/remote/free_tv_m3u_remote_data_source.dart';
import 'package:stream_hub/data/sources/free_tv_api_config.dart';
import 'package:stream_hub/data/sources/free_tv_sources.dart';

/// Utility service to fetch and convert a remote M3U playlist into raw JSON-compatible maps.
///
/// Useful for debugging, data exploration, and seeding offline cache fixtures.
class FreeTvM3uConverter {
  static Future<List<Map<String, dynamic>>> convertUrlToJson(
    String url, {
    Duration timeout = FreeTvApiConfig.defaultTimeout,
  }) async {
    final source = FreeTvSource(
      id: 'temp_conversion',
      name: 'Temporary Conversion',
      url: url,
      kind: FreeTvSourceKind.global,
    );
    final dataSource = CustomM3uFreeTvRemoteDataSource(source: source);
    final channels = await dataSource.fetchOnlineChannels(timeout: timeout);
    return channels.map((c) => c.toJson()).toList();
  }
}
