import 'package:flutter/material.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_radius.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final double? width;
  final double? height;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseDecoration = isDark
        ? AppDecorations.cardDecorationDark
        : AppDecorations.cardDecorationLight;

    final decoration =
        color != null ? baseDecoration.copyWith(color: color) : baseDecoration;

    Widget cardContent = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16.0),
      decoration: decoration,
      child: child,
    );

    if (onTap != null) {
      cardContent = ClipRRect(
        borderRadius: AppRadius.medium,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.medium,
            child: cardContent,
          ),
        ),
      );
    }

    if (margin != null) {
      cardContent = Padding(
        padding: margin!,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
