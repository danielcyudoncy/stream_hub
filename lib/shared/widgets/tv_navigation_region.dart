import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/services/tv_navigation_service.dart';

/// Scopes a widget tree (such as a carousel row, hero banner, or category bar)
/// into a named TV focus region with focus memory and horizontal intent preservation.
class TvNavigationRegion extends StatefulWidget {
  final String regionId;
  final TvFocusRegionType type;
  final Widget child;
  final bool enableInterRailNavigation;

  const TvNavigationRegion({
    super.key,
    required this.regionId,
    this.type = TvFocusRegionType.rail,
    required this.child,
    this.enableInterRailNavigation = true,
  });

  /// Finds the nearest [TvNavigationRegion] ancestor.
  static TvNavigationRegionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TvNavigationRegionScope>();

  @override
  State<TvNavigationRegion> createState() => _TvNavigationRegionState();
}

class _TvNavigationRegionState extends State<TvNavigationRegion> {
  TvNavigationService? _navService;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<TvNavigationService>()) {
      _navService = Get.find<TvNavigationService>();
      _navService?.registerRegion(widget.regionId, widget.type);
    }
  }

  @override
  void didUpdateWidget(TvNavigationRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.regionId != widget.regionId) {
      _navService?.unregisterRegion(oldWidget.regionId);
      _navService?.registerRegion(widget.regionId, widget.type);
    }
  }

  @override
  void dispose() {
    _navService?.unregisterRegion(widget.regionId);
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enableInterRailNavigation || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final isDown = event.logicalKey == LogicalKeyboardKey.arrowDown;
    final isUp = event.logicalKey == LogicalKeyboardKey.arrowUp;

    if (!isDown && !isUp) return KeyEventResult.ignored;

    final nav = _navService;
    if (nav == null) return KeyEventResult.ignored;

    final handled = nav.handleInterRailNavigation(
      currentRegionId: widget.regionId,
      direction: isDown ? TraversalDirection.down : TraversalDirection.up,
    );

    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return TvNavigationRegionScope(
      regionId: widget.regionId,
      type: widget.type,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _handleKeyEvent,
        child: widget.child,
      ),
    );
  }
}

/// InheritedWidget providing region metadata down to [TvFocusable] children.
class TvNavigationRegionScope extends InheritedWidget {
  final String regionId;
  final TvFocusRegionType type;

  const TvNavigationRegionScope({
    super.key,
    required this.regionId,
    required this.type,
    required super.child,
  });

  @override
  bool updateShouldNotify(TvNavigationRegionScope oldWidget) =>
      regionId != oldWidget.regionId || type != oldWidget.type;
}
