import 'package:stream_hub/core/media/media_source.dart';

abstract class MediaSourceRepository {
  Future<void> register(MediaSource source);
  Future<void> unregister(String sourceId);
  Future<MediaSource?> getById(String sourceId);
  Future<List<MediaSource>> getAll();
  Future<List<MediaSource>> getEnabled();
  Future<void> updateState(String sourceId, dynamic state);
  Future<void> delete(String sourceId);
  Future<void> clear();
}
