import 'package:stream_hub/core/media/media_source.dart';

abstract class MediaSourceRegistry {
  void register(MediaSource source);
  void unregister(String sourceId);
  MediaSource? lookup(String sourceId);
  List<MediaSource> getAll();
  List<MediaSource> getEnabled();
}
