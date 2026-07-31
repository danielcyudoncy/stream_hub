import 'package:stream_hub/core/media/stream_resolver.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playable_stream.dart';

class M3UStreamResolver implements StreamResolver {
  @override
  Future<PlayableStream> resolve(MediaItem item) async {
    final url = _extractStreamUrl(item);
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

  String _extractStreamUrl(MediaItem item) {
    final url = item.metadata['stream_url'] as String?;
    if (url != null && url.isNotEmpty) return url;
    return item.id;
  }

  Map<String, String>? _extractHeaders(MediaItem item) {
    final headersStr = item.metadata['headers'] as Map<String, dynamic>?;
    if (headersStr == null || headersStr.isEmpty) return null;
    return headersStr.map((k, v) => MapEntry(k, v.toString()));
  }
}
