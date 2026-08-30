import 'package:flutter/material.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../loading/loading_indicator.dart';
import 'tv_focusable.dart';

enum ButtonType { primary, secondary, text, danger }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double height;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = ButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 48.0,
  });

  const AppButton.primary({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 42.0,
  }) : type = ButtonType.primary;

  const AppButton.secondary({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 42.0,
  }) : type = ButtonType.secondary;

  const AppButton.text({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 42.0,
  }) : type = ButtonType.text;

  const AppButton.danger({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 42.0,
  }) : type = ButtonType.danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color backgroundColor;
    Color foregroundColor;
    BorderSide borderSide = BorderSide.none;

    switch (type) {
      case ButtonType.primary:
        backgroundColor = colorScheme.primary;
        foregroundColor = colorScheme.onPrimary;
        break;
      case ButtonType.secondary:
        backgroundColor = Colors.transparent;
        foregroundColor = colorScheme.secondary;
        borderSide = BorderSide(color: colorScheme.secondary, width: 1.5);
        break;
      case ButtonType.text:
        backgroundColor = Colors.transparent;
        foregroundColor = colorScheme.primary;
        break;
      case ButtonType.danger:
        backgroundColor = colorScheme.error;
        foregroundColor = colorScheme.onError;
        break;
    }

    final isButtonDisabled = onPressed == null || isLoading;

    return TvFocusable(
      onTap: isButtonDisabled ? null : onPressed,
      borderRadius: AppRadius.medium,
      scale: 1.03,
      child: SizedBox(
        width: width,
        height: height,
        child: OutlinedButton(
          onPressed: isButtonDisabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: isButtonDisabled
                ? (type == ButtonType.text || type == ButtonType.secondary
                      ? Colors.transparent
                      : colorScheme.onSurface.withValues(alpha: 0.12))
                : backgroundColor,
            foregroundColor: isButtonDisabled
                ? colorScheme.onSurface.withValues(alpha: 0.38)
                : foregroundColor,
            side: isButtonDisabled ? BorderSide.none : borderSide,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.medium),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          ),
          child: isLoading
              ? const LoadingIndicator(size: 20.0, strokeWidth: 2.0)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18.0),
                      AppSpacing.widthXS,
                    ],
                    Flexible(
                      child: Text(
                        text,
                        style: AppTypography.getButton(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
