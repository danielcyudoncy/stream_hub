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
  final bool autofocusCancel;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
    this.autofocusCancel = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
        title: Text(
          title,
          style: AppTypography.getHeadline(color: colorScheme.onSurface),
        ),
        content: Text(
          message,
          style: AppTypography.getBody(
            color: colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            autofocus: autofocusCancel,
            onPressed: onCancel ?? () => Get.back(),
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              ),
              shape: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return RoundedRectangleBorder(
                    borderRadius: AppRadius.medium,
                    side: const BorderSide(color: Colors.white, width: 2.5),
                  );
                }
                return RoundedRectangleBorder(
                  borderRadius: AppRadius.medium,
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                );
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return colorScheme.surfaceContainerHighest;
                }
                return Colors.transparent;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return Colors.white;
                }
                return colorScheme.onSurface;
              }),
            ),
            child: Text(cancelText),
          ),
          FilledButton(
            autofocus: !autofocusCancel,
            onPressed: onConfirm,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              ),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                final base = isDestructive
                    ? colorScheme.error
                    : colorScheme.primary;
                if (states.contains(WidgetState.focused)) {
                  return isDestructive
                      ? colorScheme.error
                      : colorScheme.primaryContainer;
                }
                return base;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                return isDestructive
                    ? colorScheme.onError
                    : colorScheme.onPrimary;
              }),
              shape: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return RoundedRectangleBorder(
                    borderRadius: AppRadius.medium,
                    side: const BorderSide(color: Colors.white, width: 3.0),
                  );
                }
                return RoundedRectangleBorder(borderRadius: AppRadius.medium);
              }),
              elevation: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return 8.0;
                }
                return 0.0;
              }),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
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
