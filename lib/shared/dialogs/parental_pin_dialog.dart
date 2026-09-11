import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

enum ParentalPinDialogMode {
  unlock,
  setPin,
  changePin,
  disable,
}

class ParentalPinDialog extends StatefulWidget {
  final ParentalPinDialogMode mode;
  final String? title;
  final String? message;
  final Future<bool> Function(String pin)? onValidate;
  final Future<bool> Function(String pin)? onSetPin;
  final Future<bool> Function(String currentPin, String newPin)? onChangePin;

  const ParentalPinDialog({
    super.key,
    required this.mode,
    this.title,
    this.message,
    this.onValidate,
    this.onSetPin,
    this.onChangePin,
  });

  static Future<bool?> showUnlockDialog({
    BuildContext? context,
    String title = 'Parental Lock',
    String message = 'Enter your 4-digit PIN to proceed.',
    required Future<bool> Function(String pin) onValidate,
  }) {
    return showDialog<bool>(
      context: context ?? Get.context!,
      barrierDismissible: false,
      builder: (context) => ParentalPinDialog(
        mode: ParentalPinDialogMode.unlock,
        title: title,
        message: message,
        onValidate: onValidate,
      ),
    );
  }

  static Future<bool?> showSetPinDialog({
    BuildContext? context,
    String title = 'Set Parental PIN',
    String message = 'Enter a 4-digit security PIN to restrict access.',
    required Future<bool> Function(String pin) onSetPin,
  }) {
    return showDialog<bool>(
      context: context ?? Get.context!,
      barrierDismissible: false,
      builder: (context) => ParentalPinDialog(
        mode: ParentalPinDialogMode.setPin,
        title: title,
        message: message,
        onSetPin: onSetPin,
      ),
    );
  }

  static Future<bool?> showChangePinDialog({
    BuildContext? context,
    String title = 'Change Parental PIN',
    String message = 'Enter your current PIN followed by a new 4-digit PIN.',
    required Future<bool> Function(String currentPin, String newPin) onChangePin,
  }) {
    return showDialog<bool>(
      context: context ?? Get.context!,
      barrierDismissible: false,
      builder: (context) => ParentalPinDialog(
        mode: ParentalPinDialogMode.changePin,
        title: title,
        message: message,
        onChangePin: onChangePin,
      ),
    );
  }

  static Future<bool?> showDisableDialog({
    BuildContext? context,
    String title = 'Disable Parental Lock',
    String message = 'Enter your current PIN to turn off Parental Lock.',
    required Future<bool> Function(String pin) onValidate,
  }) {
    return showDialog<bool>(
      context: context ?? Get.context!,
      barrierDismissible: false,
      builder: (context) => ParentalPinDialog(
        mode: ParentalPinDialogMode.disable,
        title: title,
        message: message,
        onValidate: onValidate,
      ),
    );
  }

  @override
  State<ParentalPinDialog> createState() => _ParentalPinDialogState();
}

class _ParentalPinDialogState extends State<ParentalPinDialog> {
  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  bool _obscureCurrentPin = true;
  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;

  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _errorMessage = null;
    });

    switch (widget.mode) {
      case ParentalPinDialogMode.unlock:
      case ParentalPinDialogMode.disable:
        final pin = _currentPinController.text.trim();
        if (pin.length != 4) {
          setState(() {
            _errorMessage = 'PIN must be 4 digits.';
          });
          return;
        }

        setState(() {
          _isProcessing = true;
        });

        final valid = await widget.onValidate?.call(pin) ?? false;
        if (!mounted) return;

        setState(() {
          _isProcessing = false;
        });

        if (valid) {
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _errorMessage = 'Incorrect PIN. Please try again.';
            _currentPinController.clear();
          });
        }
        break;

      case ParentalPinDialogMode.setPin:
        final newPin = _newPinController.text.trim();
        final confirmPin = _confirmPinController.text.trim();

        if (newPin.length != 4) {
          setState(() {
            _errorMessage = 'PIN must be 4 digits.';
          });
          return;
        }

        if (newPin != confirmPin) {
          setState(() {
            _errorMessage = 'PINs do not match. Please try again.';
            _confirmPinController.clear();
          });
          return;
        }

        setState(() {
          _isProcessing = true;
        });

        final success = await widget.onSetPin?.call(newPin) ?? false;
        if (!mounted) return;

        setState(() {
          _isProcessing = false;
        });

        if (success) {
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _errorMessage = 'Failed to save PIN. Please try again.';
          });
        }
        break;

      case ParentalPinDialogMode.changePin:
        final currentPin = _currentPinController.text.trim();
        final newPin = _newPinController.text.trim();
        final confirmPin = _confirmPinController.text.trim();

        if (currentPin.length != 4) {
          setState(() {
            _errorMessage = 'Current PIN must be 4 digits.';
          });
          return;
        }

        if (newPin.length != 4) {
          setState(() {
            _errorMessage = 'New PIN must be 4 digits.';
          });
          return;
        }

        if (newPin != confirmPin) {
          setState(() {
            _errorMessage = 'New PINs do not match.';
            _confirmPinController.clear();
          });
          return;
        }

        setState(() {
          _isProcessing = true;
        });

        final success =
            await widget.onChangePin?.call(currentPin, newPin) ?? false;
        if (!mounted) return;

        setState(() {
          _isProcessing = false;
        });

        if (success) {
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _errorMessage = 'Incorrect current PIN. Please try again.';
            _currentPinController.clear();
          });
        }
        break;
    }
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required String label,
    required ColorScheme colorScheme,
    required bool obscureText,
    required VoidCallback onToggleObscure,
    bool autofocus = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.getCaption(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        AppSpacing.heightXS,
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: obscureText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22.0,
            letterSpacing: 8.0,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: obscureText ? '••••' : '0000',
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: AppRadius.medium,
              borderSide: BorderSide.none,
            ),
            counterText: '',
            prefixIcon: const SizedBox(width: 48),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              onPressed: onToggleObscure,
              tooltip: obscureText ? 'Show PIN' : 'Hide PIN',
            ),
          ),
          onSubmitted: (_) {
            if (widget.mode == ParentalPinDialogMode.unlock ||
                widget.mode == ParentalPinDialogMode.disable) {
              _handleSubmit();
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String dialogTitle = widget.title ?? 'Parental PIN';
    String confirmButtonText = 'Confirm';

    switch (widget.mode) {
      case ParentalPinDialogMode.unlock:
        dialogTitle = widget.title ?? 'Parental Lock';
        confirmButtonText = 'Unlock';
        break;
      case ParentalPinDialogMode.setPin:
        dialogTitle = widget.title ?? 'Set Parental PIN';
        confirmButtonText = 'Save PIN';
        break;
      case ParentalPinDialogMode.changePin:
        dialogTitle = widget.title ?? 'Change PIN';
        confirmButtonText = 'Update PIN';
        break;
      case ParentalPinDialogMode.disable:
        dialogTitle = widget.title ?? 'Disable Parental Lock';
        confirmButtonText = 'Disable';
        break;
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
      title: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
          AppSpacing.widthSM,
          Expanded(
            child: Text(
              dialogTitle,
              style: AppTypography.getHeadline(color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null && widget.message!.isNotEmpty) ...[
              Text(
                widget.message!,
                style: AppTypography.getBody(
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              AppSpacing.heightMD,
            ],
            if (widget.mode == ParentalPinDialogMode.unlock ||
                widget.mode == ParentalPinDialogMode.disable) ...[
              _buildPinField(
                controller: _currentPinController,
                label: 'Enter 4-digit PIN',
                colorScheme: colorScheme,
                obscureText: _obscureCurrentPin,
                onToggleObscure: () {
                  setState(() {
                    _obscureCurrentPin = !_obscureCurrentPin;
                  });
                },
                autofocus: true,
              ),
            ] else if (widget.mode == ParentalPinDialogMode.setPin) ...[
              _buildPinField(
                controller: _newPinController,
                label: 'Create 4-digit PIN',
                colorScheme: colorScheme,
                obscureText: _obscureNewPin,
                onToggleObscure: () {
                  setState(() {
                    _obscureNewPin = !_obscureNewPin;
                  });
                },
                autofocus: true,
              ),
              AppSpacing.heightSM,
              _buildPinField(
                controller: _confirmPinController,
                label: 'Confirm 4-digit PIN',
                colorScheme: colorScheme,
                obscureText: _obscureConfirmPin,
                onToggleObscure: () {
                  setState(() {
                    _obscureConfirmPin = !_obscureConfirmPin;
                  });
                },
              ),
            ] else if (widget.mode == ParentalPinDialogMode.changePin) ...[
              _buildPinField(
                controller: _currentPinController,
                label: 'Current 4-digit PIN',
                colorScheme: colorScheme,
                obscureText: _obscureCurrentPin,
                onToggleObscure: () {
                  setState(() {
                    _obscureCurrentPin = !_obscureCurrentPin;
                  });
                },
                autofocus: true,
              ),
              AppSpacing.heightSM,
              _buildPinField(
                controller: _newPinController,
                label: 'New 4-digit PIN',
                colorScheme: colorScheme,
                obscureText: _obscureNewPin,
                onToggleObscure: () {
                  setState(() {
                    _obscureNewPin = !_obscureNewPin;
                  });
                },
              ),
              AppSpacing.heightSM,
              _buildPinField(
                controller: _confirmPinController,
                label: 'Confirm New 4-digit PIN',
                colorScheme: colorScheme,
                obscureText: _obscureConfirmPin,
                onToggleObscure: () {
                  setState(() {
                    _obscureConfirmPin = !_obscureConfirmPin;
                  });
                },
              ),
            ],
            if (_errorMessage != null) ...[
              AppSpacing.heightSM,
              Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: colorScheme.error),
                  AppSpacing.widthXS,
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTypography.getCaption(
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TvFocusable(
          borderRadius: AppRadius.medium,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _handleSubmit,
            child: _isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(confirmButtonText),
          ),
        ),
      ],
    );
  }
}
