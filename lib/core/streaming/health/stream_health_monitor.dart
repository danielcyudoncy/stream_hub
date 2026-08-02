import 'dart:async';
import 'package:stream_hub/core/streaming/events/stream_event_bus.dart';
import 'package:stream_hub/core/streaming/events/stream_events.dart';
import 'package:stream_hub/core/streaming/models/stream_health_snapshot.dart';

/// Tracks per-session stream health: availability, latency, response time,
/// failures, retries, average speed, and current bitrate.
class StreamHealthMonitor {
  final StreamEventBus _eventBus;
  final Map<String, _HealthTracker> _trackers = {};

  final StreamController<StreamHealthSnapshot> _updates =
      StreamController<StreamHealthSnapshot>.broadcast();

  StreamHealthMonitor({StreamEventBus? eventBus})
    : _eventBus = eventBus ?? StreamEventBus();

  /// Emits a health snapshot whenever it changes.
  Stream<StreamHealthSnapshot> get updates => _updates.stream;

  void startSession(String sessionId) {
    _trackers[sessionId] = _HealthTracker(sessionId);
  }

  void stopSession(String sessionId) {
    _trackers.remove(sessionId);
  }

  void recordSuccess(
    String sessionId, {
    int? latencyMs,
    int? responseTimeMs,
    int? bytesDownloaded,
  }) {
    final tracker = _trackers[sessionId];
    if (tracker == null) return;
    tracker.recordSuccess(
      latencyMs: latencyMs,
      responseTimeMs: responseTimeMs,
      bytesDownloaded: bytesDownloaded,
    );
    _emit(tracker.snapshot());
  }

  void recordFailure(String sessionId, {int? latencyMs, String? error}) {
    final tracker = _trackers[sessionId];
    if (tracker == null) return;
    tracker.recordFailure(latencyMs: latencyMs, error: error);
    _emit(tracker.snapshot());
  }

  void recordRetry(String sessionId) {
    final tracker = _trackers[sessionId];
    if (tracker == null) return;
    tracker.recordRetry();
    _emit(tracker.snapshot());
  }

  void updateBitrate(String sessionId, int bitrateKbps) {
    final tracker = _trackers[sessionId];
    if (tracker == null) return;
    tracker.updateBitrate(bitrateKbps);
    _emit(tracker.snapshot());
  }

  void updateSpeed(String sessionId, double speedKbps) {
    final tracker = _trackers[sessionId];
    if (tracker == null) return;
    tracker.updateSpeed(speedKbps);
    _emit(tracker.snapshot());
  }

  StreamHealthSnapshot? snapshotFor(String sessionId) {
    return _trackers[sessionId]?.snapshot();
  }

  List<StreamHealthSnapshot> allSnapshots() {
    return _trackers.values.map((t) => t.snapshot()).toList();
  }

  void reset(String sessionId) {
    final tracker = _trackers[sessionId];
    if (tracker != null) tracker.reset();
  }

  void dispose() {
    _trackers.clear();
    if (!_updates.isClosed) {
      _updates.close();
    }
  }

  void _emit(StreamHealthSnapshot snapshot) {
    if (!_updates.isClosed) {
      _updates.add(snapshot);
    }
    _eventBus.publish(
      HealthUpdatedEvent(
        sessionId: snapshot.sessionId,
        health: snapshot,
        occurredAt: DateTime.now(),
      ),
    );
  }
}

class _HealthTracker {
  final String sessionId;

  bool _available = false;
  int _latencyMs = 0;
  int _responseTimeMs = 0;
  int _failures = 0;
  int _retries = 0;
  double _averageSpeedKbps = 0;
  int _currentBitrateKbps = 0;
  int _totalBytes = 0;
  int _totalSamples = 0;
  String? _lastError;

  _HealthTracker(this.sessionId);

  void recordSuccess({
    int? latencyMs,
    int? responseTimeMs,
    int? bytesDownloaded,
  }) {
    _available = true;
    if (latencyMs != null) _latencyMs = latencyMs;
    if (responseTimeMs != null) _responseTimeMs = responseTimeMs;
    if (bytesDownloaded != null && bytesDownloaded > 0) {
      _totalBytes += bytesDownloaded;
      _totalSamples++;
      if (_totalSamples > 0) {
        _averageSpeedKbps = _totalBytes / _totalSamples / 128.0;
      }
    }
    _lastError = null;
  }

  void recordFailure({int? latencyMs, String? error}) {
    _available = false;
    _failures++;
    if (latencyMs != null) _latencyMs = latencyMs;
    _lastError = error;
  }

  void recordRetry() {
    _retries++;
  }

  void updateBitrate(int bitrateKbps) {
    _currentBitrateKbps = bitrateKbps;
  }

  void updateSpeed(double speedKbps) {
    _averageSpeedKbps = speedKbps;
  }

  void reset() {
    _available = false;
    _latencyMs = 0;
    _responseTimeMs = 0;
    _failures = 0;
    _retries = 0;
    _averageSpeedKbps = 0;
    _currentBitrateKbps = 0;
    _totalBytes = 0;
    _totalSamples = 0;
    _lastError = null;
  }

  StreamHealthSnapshot snapshot() {
    return StreamHealthSnapshot(
      sessionId: sessionId,
      isAvailable: _available,
      latencyMs: _latencyMs,
      responseTimeMs: _responseTimeMs,
      failures: _failures,
      retries: _retries,
      averageSpeedKbps: _averageSpeedKbps,
      currentBitrateKbps: _currentBitrateKbps,
      lastError: _lastError,
      sampledAt: DateTime.now(),
    );
  }
}
