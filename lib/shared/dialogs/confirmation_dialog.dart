import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_typography.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
      title: Text(title, style: AppTypography.getHeadline(color: colorScheme.onSurface)),
      content: Text(message, style: AppTypography.getBody(color: colorScheme.onSurface.withValues(alpha: 0.8))),
      actions: [
        TextButton(onPressed: onCancel ?? () => Get.back(), child: Text(cancelText)),
        FilledButton(
          onPressed: onConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: isDestructive ? colorScheme.error : colorScheme.primary,
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }
}

class DeleteDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onConfirm;

  const DeleteDialog({
    super.key,
    required this.title,
    required this.message,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return ConfirmationDialog(
      title: title,
      message: message,
      confirmText: 'Delete',
      isDestructive: true,
      onCancel: () => Navigator.of(context).pop(false),
      onConfirm: () {
        onConfirm?.call();
        Navigator.of(context).pop(true);
      },
    );
  }
}
