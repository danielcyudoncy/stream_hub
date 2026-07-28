import 'package:stream_hub/data/models/media_sync_result.dart';

abstract class SyncService {
  Future<void> manualSync(String sourceId);
  Future<void> autoSync();
  Future<void> scheduledSync();
  Future<MediaSyncResult> incrementalSync(String sourceId);
  Future<void> backgroundSync();
  Future<void> retry(String sourceId);
}
