import 'dart:async';
import 'package:stream_hub/core/streaming/events/stream_events.dart';

/// Broadcast bus for [StreamEvent]s published by the Stream Engine.
class StreamEventBus {
  final StreamController<StreamEvent> _controller =
      StreamController<StreamEvent>.broadcast();

  Stream<StreamEvent> get stream => _controller.stream;

  void publish(StreamEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  Stream<T> ofType<T extends StreamEvent>() {
    return _controller.stream.where((event) => event is T).cast<T>();
  }

  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
