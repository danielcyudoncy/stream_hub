import 'package:floating/floating.dart';

/// Interface implemented by player adapters that support Picture-in-Picture
/// mode via the [Floating] controller.
abstract interface class PipFloatingCapable {
  /// Injects the [Floating] instance initialized by the active player page.
  void setFloating(Floating floating);
}
