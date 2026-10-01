import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_radius.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? border;
  final Color? backgroundColor;

  const GlassPanel({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.8,
    this.borderRadius,
    this.padding,
    this.border,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = backgroundColor ?? theme.colorScheme.surface;
    final defaultBorder = border ??
        (theme.brightness == Brightness.dark
            ? AppDecorations.glassBorder
            : Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.12),
                width: 1.0,
              ));

    return ClipRRect(
      borderRadius: borderRadius ?? AppRadius.medium,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: surfaceColor.withValues(alpha: opacity),
            borderRadius: borderRadius ?? AppRadius.medium,
            border: defaultBorder,
          ),
          child: child,
        ),
      ),
    );
  }
}
