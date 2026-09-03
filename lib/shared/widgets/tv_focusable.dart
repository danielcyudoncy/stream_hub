import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';

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
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _hasFocus = false;
  Timer? _longPressTimer;
  bool _longPressTriggered = false;

  FocusNode? _internalFocusNode;
  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.onKeyEvent != null) {
      final res = widget.onKeyEvent!(node, event);
      if (res != KeyEventResult.ignored) return res;
    }

    if (widget.onLongPress == null) return KeyEventResult.ignored;

    final isSelect = event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA;

    if (!isSelect) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final focusColor = widget.focusColor ?? colorScheme.primary;
    final borderRadius = widget.borderRadius ?? AppRadius.medium;

    final node = _effectiveFocusNode;
    node.onKeyEvent = _handleKeyEvent;

    return FocusableActionDetector(
      autofocus: widget.autofocus,
      focusNode: node,
      descendantsAreFocusable: widget.descendantsAreFocusable,
      enabled: widget.canRequestFocus,
      onFocusChange: (hasKeyboardFocus) {
        if (mounted && _hasFocus != hasKeyboardFocus) {
          setState(() => _hasFocus = hasKeyboardFocus);
          if (hasKeyboardFocus) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
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
      },
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
