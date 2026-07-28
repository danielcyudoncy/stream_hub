abstract class MediaEventBus {
  void subscribe<T>(void Function(T event) listener);
  void unsubscribe<T>(void Function(T event) listener);
  void publish<T>(T event);
  void dispose();
}