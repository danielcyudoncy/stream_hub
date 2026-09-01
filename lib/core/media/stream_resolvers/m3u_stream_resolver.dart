import 'package:stream_hub/core/media/stream_resolver.dart';
import 'package:stream_hub/data/models/channel.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playable_stream.dart';

class M3UStreamResolver implements StreamResolver {
  @override
  Future<PlayableStream> resolve(MediaItem item) async {
    final url = _extractStreamUrl(item);
    if (url == null || url.isEmpty) {
      throw Exception(
        'M3UStreamResolver: no resolvable stream URL for item "${item.title}" (${item.id}). '
        'Ensure the MediaItem metadata contains a streamUrl, stream_url, or url key.',
      );
    }
    final headers = _extractHeaders(item);
    return PlayableStream(
      url: url,
      headers: headers,
    );
  }

  @override
  Future<bool> validate(PlayableStream stream) async {
    try {
      final uri = Uri.parse(stream.url);
      return uri.isAbsolute &&
          (uri.scheme == 'http' ||
              uri.scheme == 'https' ||
              uri.scheme == 'rtmp' ||
              uri.scheme == 'rtsp');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> prepare(PlayableStream stream) async {
    // No preparation needed for HLS/MPEG-TS streams
  }

  String? _extractStreamUrl(MediaItem item) {
    // Check typed field first (Channel subclass)
    if (item is Channel && item.streamUrl != null && item.streamUrl!.isNotEmpty) {
      return item.streamUrl;
    }
    // Check all common metadata key variants
    final candidates = <String?>[
      item.metadata['streamUrl']?.toString(),
      item.metadata['stream_url']?.toString(),
      item.metadata['url']?.toString(),
      item.metadata['directSource']?.toString(),
      item.metadata['direct_source']?.toString(),
    ];
    for (final candidate in candidates) {
      if (candidate != null && candidate.isNotEmpty) return candidate;
    }
    return null;
  }

  Map<String, String>? _extractHeaders(MediaItem item) {
    final headersStr = item.metadata['headers'] as Map<String, dynamic>?;
    if (headersStr == null || headersStr.isEmpty) return null;
    return headersStr.map((k, v) => MapEntry(k, v.toString()));
  }
}
