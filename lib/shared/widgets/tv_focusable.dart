import 'package:flutter/material.dart';
import '../../core/helpers/platform_helper.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';

class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;
  final BorderRadius? borderRadius;
  final Color? focusColor;
  final ValueChanged<bool>? onFocusChange;

  const TvFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 1.1,
    this.duration = const Duration(milliseconds: 200),
    this.borderRadius,
    this.focusColor,
    this.onFocusChange,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    if (!PlatformHelper.isTV) {
      return GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: widget.child,
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final focusColor = widget.focusColor ?? colorScheme.primary;
    final borderRadius = widget.borderRadius ?? AppRadius.medium;

    return FocusableActionDetector(
      onShowFocusHighlight: (show) {
        if (mounted && _hasFocus != show) {
          setState(() => _hasFocus = show);
          if (widget.onFocusChange != null) {
            widget.onFocusChange!(show);
          }
        }
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<Intent>(
          onInvoke: (Intent intent) {
            if (widget.onTap != null) {
              widget.onTap!();
            }
            return null;
          },
        ),
      },
      mouseCursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _hasFocus ? widget.scale : 1.0,
          duration: widget.duration,
          curve: Curves.easeOut,
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
