import 'package:stream_hub/data/models/media_health.dart';

abstract class HealthService {
  Future<MediaHealth> checkHealth(String sourceId);
  Future<List<MediaHealth>> checkAll();
  Stream<MediaHealth> monitor(String sourceId);
  Future<void> startMonitoring(String sourceId, Duration interval);
  Future<void> stopMonitoring(String sourceId);
}
