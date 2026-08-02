import 'dart:async';

import 'package:get/get.dart';
import 'package:stream_hub/core/streaming/events/stream_events.dart';
import 'package:stream_hub/core/streaming/models/stream_health_snapshot.dart';
import 'package:stream_hub/core/streaming/stream_engine.dart';

/// Tracks the live health of the currently active stream session.
class StreamHealthController extends GetxController {
  final StreamEngine engine;
  StreamSubscription<StreamEvent>? _subscription;

  final Rx<StreamHealthSnapshot?> currentHealth = Rx<StreamHealthSnapshot?>(
    null,
  );
  final RxBool isHealthy = false.obs;

  StreamHealthController(this.engine);

  @override
  void onInit() {
    super.onInit();
    _subscription = engine.eventBus.ofType<HealthUpdatedEvent>().listen((
      event,
    ) {
      final snapshot = engine.healthFor(event.sessionId);
      if (snapshot != null) {
        currentHealth.value = snapshot;
        isHealthy.value = snapshot.isHealthy;
      }
    });
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  void attachSession(String sessionId) {
    final snapshot = engine.healthFor(sessionId);
    if (snapshot != null) {
      currentHealth.value = snapshot;
      isHealthy.value = snapshot.isHealthy;
    }
  }

  void detach() {
    currentHealth.value = null;
    isHealthy.value = false;
  }
}
