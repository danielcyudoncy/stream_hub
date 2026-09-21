import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stream_hub/shared/widgets/tv_navigation_region.dart';

/// Debug-only ingress telemetry for remote / keyboard navigation.
///
/// Reasons to exist: on desktop windows below the TvScaffold width threshold
/// (>= 1024 logical px) the app relies on Flutter's plain focus traversal, and
/// a D-pad "freeze" there is notoriously hard to reproduce in widget tests
/// (async content mount, focus loss during rebuilds, unhandled keys, …). This
/// widget records every directional / activation / back key at the
/// [HardwareKeyboard] ingress point -- BEFORE focus routing -- together with
/// the currently focused node (and its TV navigation region, when any), so a
/// single real-device run tells us definitively whether keys reach the app and
/// whether primary focus is live or stuck.
///
/// Everything is gated on [kDebugMode]; release builds are completely inert.
/// No focus is ever requested or mutated here -- it only observes.
class TvRemoteKeyTelemetry extends StatefulWidget {
  const TvRemoteKeyTelemetry({super.key, required this.child});

  final Widget child;

  @override
  State<TvRemoteKeyTelemetry> createState() => _TvRemoteKeyTelemetryState();
}

class _TvRemoteKeyTelemetryState extends State<TvRemoteKeyTelemetry> {
  KeyEventCallback? _traceHandler;

  static final _interestingKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.gameButtonA,
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.goBack,
  };

  @override
  void initState() {
    super.initState();
    _traceHandler = _trace;
    HardwareKeyboard.instance.addHandler(_traceHandler!);
  }

  @override
  void dispose() {
    if (_traceHandler != null) {
      HardwareKeyboard.instance.removeHandler(_traceHandler!);
    }
    super.dispose();
  }

  bool _trace(KeyEvent event) {
    if (!kDebugMode) return false;
    if (event is! KeyDownEvent) return false;
    if (!_interestingKeys.contains(event.logicalKey)) return false;

    final focus = FocusManager.instance.primaryFocus;

    String? region;
    final ctx = focus?.context;
    if (ctx != null) {
      final scope = ctx.findAncestorWidgetOfExactType<TvNavigationRegionScope>();
      region = scope?.regionId;
    }

    final label = focus != null
        ? (focus.debugLabel ?? focus.toStringShort())
        : 'NONE';
    final regionSuffix = region != null ? ' region=$region' : '';
    final keyName = _keyDebugName(event.logicalKey);
    debugPrint('[TV-Key] $keyName primaryFocus=$label$regionSuffix');
    return false;
  }

  static String _keyDebugName(LogicalKeyboardKey key) => switch (key) {
    LogicalKeyboardKey.arrowUp => 'ArrowUp',
    LogicalKeyboardKey.arrowDown => 'ArrowDown',
    LogicalKeyboardKey.arrowLeft => 'ArrowLeft',
    LogicalKeyboardKey.arrowRight => 'ArrowRight',
    LogicalKeyboardKey.select => 'Select',
    LogicalKeyboardKey.enter => 'Enter',
    LogicalKeyboardKey.numpadEnter => 'NumpadEnter',
    LogicalKeyboardKey.gameButtonA => 'GameButtonA',
    LogicalKeyboardKey.escape => 'Escape',
    LogicalKeyboardKey.goBack => 'GoBack',
    _ => key.keyLabel,
  };

  @override
  Widget build(BuildContext context) => widget.child;
}