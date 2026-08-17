import 'package:flutter/material.dart';
import '../../core/helpers/platform_helper.dart';
import '../../core/theme/app_radius.dart';

class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;
  final BorderRadius? borderRadius;
  final Color? focusColor;

  const TvFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 1.05,
    this.duration = const Duration(milliseconds: 200),
    this.borderRadius,
    this.focusColor,
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
        }
      },
      mouseCursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: widget.duration,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: _hasFocus
                ? Border.all(color: focusColor, width: 3.0)
                : null,
            boxShadow: _hasFocus
                ? [
                    BoxShadow(
                      color: focusColor.withValues(alpha: 0.35),
                      blurRadius: 20.0,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
