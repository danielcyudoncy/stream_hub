import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/services/tv_navigation_service.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import 'tv_body_focus_registry.dart';
import 'tv_navigation_region.dart';

class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final Duration duration;
  final BorderRadius? borderRadius;
  final Color? focusColor;
  final ValueChanged<bool>? onFocusChange;
  final bool autofocus;
  final bool canRequestFocus;
  final bool descendantsAreFocusable;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;
  final String? regionId;
  final String? itemId;
  final int? itemIndex;

  const TvFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 1.08,
    this.duration = const Duration(milliseconds: 200),
    this.borderRadius,
    this.focusColor,
    this.onFocusChange,
    this.autofocus = false,
    this.canRequestFocus = true,
    this.descendantsAreFocusable = true,
    this.focusNode,
    this.onKeyEvent,
    this.regionId,
    this.itemId,
    this.itemIndex,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _hasFocus = false;
  Timer? _longPressTimer;
  bool _longPressTriggered = false;
  bool _registeredWithBody = false;
  bool _registeredWithNavService = false;
  String? _activeRegionId;

  FocusNode? _internalFocusNode;
  FocusNode? _handlerBoundNode;
  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode!;

  TvBodyFocusRegistry? _registry;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRegistrations();
  }

  @override
  void didUpdateWidget(TvFocusable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      // Recreate the internal node when migrating between an external and an
      // internally owned focus node so the effective node is never null.
      if (widget.focusNode == null) {
        _internalFocusNode ??= FocusNode();
      } else {
        _internalFocusNode?.dispose();
        _internalFocusNode = null;
      }
      _unregister();
      _syncRegistrations();
    } else if (oldWidget.regionId != widget.regionId) {
      _unregister();
      _syncRegistrations();
    }
  }

  void _syncRegistrations() {
    // Bind the key handler once per effective node. Binding here (rather than
    // in build()) keeps the handler attached across rebuilds without mutating
    // widget state during the build phase.
    _bindKeyHandler();
    // 1. TvBodyFocusRegistry sync (for TvScaffold)
    final registry = TvBodyFocusRegistry.maybeOf(context);
    if (registry != null) {
      _registry = registry;
      if (!_registeredWithBody) {
        _registeredWithBody = true;
        registry.register(_effectiveFocusNode);
      }
    } else {
      _unregisterWithBody();
    }

    // 2. TvNavigationService sync
    final regionScope = TvNavigationRegion.maybeOf(context);
    final effectiveRegion = widget.regionId ?? regionScope?.regionId;
    _activeRegionId = effectiveRegion;

    if (effectiveRegion != null && Get.isRegistered<TvNavigationService>()) {
      Get.find<TvNavigationService>().registerNode(
        effectiveRegion,
        _effectiveFocusNode,
      );
      _registeredWithNavService = true;
    }
  }

  void _unregisterWithBody() {
    if (!_registeredWithBody) return;
    _registry?.unregister(_effectiveFocusNode);
    _registeredWithBody = false;
    _registry = null;
  }

  void _bindKeyHandler() {
    final node = _effectiveFocusNode;
    if (_handlerBoundNode != node) {
      node.onKeyEvent = _handleKeyEvent;
      _handlerBoundNode = node;
    }
  }

  void _unregister() {
    _unregisterWithBody();
    if (_registeredWithNavService &&
        _activeRegionId != null &&
        Get.isRegistered<TvNavigationService>()) {
      Get.find<TvNavigationService>().unregisterNode(
        _activeRegionId!,
        _effectiveFocusNode,
      );
      _registeredWithNavService = false;
    }
  }

  @override
  void dispose() {
    _unregister();
    _longPressTimer?.cancel();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.onKeyEvent != null) {
      final res = widget.onKeyEvent!(node, event);
      if (res != KeyEventResult.ignored) return res;
    }

    // Without an activation handler this wrapper must not claim Select/Enter:
    // an interactive descendant (IconButton, PopupMenuButton, SwitchListTile…)
    // may own the activation. Swallowing the key here is what made such
    // controls dead on remote Enter while still showing a focus ring.
    if (widget.onTap == null && widget.onLongPress == null) {
      return KeyEventResult.ignored;
    }

    final isSelect =
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA;

    if (!isSelect) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      if (widget.onLongPress == null) {
        // Activate immediately on press (key down).
        widget.onTap?.call();
        return KeyEventResult.handled;
      }
      if (_longPressTimer == null && !_longPressTriggered) {
        _longPressTimer = Timer(const Duration(milliseconds: 600), () {
          if (mounted) {
            _longPressTriggered = true;
            widget.onLongPress?.call();
          }
        });
      }
      return KeyEventResult.handled;
    } else if (event is KeyUpEvent) {
      if (widget.onLongPress == null) {
        return KeyEventResult.handled;
      }
      final wasTriggered = _longPressTriggered;
      _longPressTimer?.cancel();
      _longPressTimer = null;
      _longPressTriggered = false;
      if (!wasTriggered) {
        widget.onTap?.call();
      }
      return KeyEventResult.handled;
    } else if (event is KeyRepeatEvent) {
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _onFocusChanged(bool hasKeyboardFocus) {
    if (!mounted || _hasFocus == hasKeyboardFocus) return;

    setState(() => _hasFocus = hasKeyboardFocus);

    if (hasKeyboardFocus) {
      // Record focus in TvNavigationService
      final effectiveRegion = _activeRegionId;
      if (effectiveRegion != null && Get.isRegistered<TvNavigationService>()) {
        Get.find<TvNavigationService>().recordFocus(
          regionId: effectiveRegion,
          node: _effectiveFocusNode,
          itemId: widget.itemId,
          itemIndex: widget.itemIndex,
        );
      }

      // Smooth scroll visibility in parent scrollables
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (Get.isRegistered<TvNavigationService>()) {
          Get.find<TvNavigationService>().ensureVisible(
            context,
            alignment: 0.5,
          );
        } else {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }

    widget.onFocusChange?.call(hasKeyboardFocus);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final focusColor = widget.focusColor ?? colorScheme.primary;
    final borderRadius = widget.borderRadius ?? AppRadius.medium;

    final node = _effectiveFocusNode;

    return FocusableActionDetector(
      autofocus: widget.autofocus,
      focusNode: node,
      descendantsAreFocusable: widget.descendantsAreFocusable,
      enabled: widget.canRequestFocus,
      onFocusChange: _onFocusChanged,
      actions: widget.onLongPress != null
          ? const <Type, Action<Intent>>{}
          : <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<Intent>(
                onInvoke: (Intent intent) {
                  widget.onTap?.call();
                  return null;
                },
              ),
              ButtonActivateIntent: CallbackAction<Intent>(
                onInvoke: (Intent intent) {
                  widget.onTap?.call();
                  return null;
                },
              ),
            },
      mouseCursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _hasFocus ? widget.scale : 1.0,
          duration: widget.duration,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: widget.duration,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: _hasFocus
                  ? Border.all(color: focusColor, width: 2.0)
                  : Border.all(color: Colors.transparent, width: 2.0),
              boxShadow: _hasFocus ? [AppShadows.neonFocusGlow] : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
