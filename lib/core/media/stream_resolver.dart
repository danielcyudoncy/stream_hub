import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playable_stream.dart';

abstract class StreamResolver {
  Future<PlayableStream> resolve(MediaItem item);
  Future<bool> validate(PlayableStream stream);
  Future<void> prepare(PlayableStream stream);
}
