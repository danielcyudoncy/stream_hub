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

  final FocusNode _currentPinFocus = FocusNode();
  final FocusNode _newPinFocus = FocusNode();
  final FocusNode _confirmPinFocus = FocusNode();

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
    _currentPinFocus.dispose();
    _newPinFocus.dispose();
    _confirmPinFocus.dispose();
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
          Navigator.of(context).maybePop(true);
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
          Navigator.of(context).maybePop(true);
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
          Navigator.of(context).maybePop(true);
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
    FocusNode? focusNode,
    TextInputAction textInputAction = TextInputAction.done,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
    bool autofocus = false,
    bool isCompact = false,
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
        SizedBox(height: isCompact ? 2 : 4),
        TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: textInputAction,
          autofocus: autofocus,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: obscureText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isCompact ? 18.0 : 22.0,
            letterSpacing: isCompact ? 6.0 : 8.0,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            isDense: isCompact,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: isCompact ? 8.0 : 12.0,
            ),
            hintText: obscureText ? '••••' : '0000',
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: AppRadius.medium,
              borderSide: BorderSide.none,
            ),
            counterText: '',
            prefixIcon: SizedBox(width: isCompact ? 36 : 48),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: isCompact ? 18 : 20,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              onPressed: onToggleObscure,
              tooltip: obscureText ? 'Show PIN' : 'Hide PIN',
            ),
          ),
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape &&
        size.height < 520;
    final isCompactWidth = size.width < 420;

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

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompactWidth ? 16.0 : 24.0,
        vertical: isLandscape ? 8.0 : 24.0,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
      backgroundColor:
          theme.dialogTheme.backgroundColor ?? colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isCompactWidth ? AppSpacing.md : AppSpacing.lg,
            vertical: isLandscape ? AppSpacing.sm : AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title Row
              Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.primary,
                    size: isLandscape ? 20 : 24,
                  ),
                  AppSpacing.widthSM,
                  Expanded(
                    child: Text(
                      dialogTitle,
                      style: isLandscape
                          ? AppTypography.getTitle(color: colorScheme.onSurface)
                          : AppTypography.getHeadline(color: colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
              if (widget.message != null && widget.message!.isNotEmpty && !isLandscape) ...[
                AppSpacing.heightSM,
                Text(
                  widget.message!,
                  style: AppTypography.getBody(
                    color: colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
              SizedBox(height: isLandscape ? 6 : 12),
              if (widget.mode == ParentalPinDialogMode.unlock ||
                  widget.mode == ParentalPinDialogMode.disable) ...[
                _buildPinField(
                  controller: _currentPinController,
                  focusNode: _currentPinFocus,
                  label: 'Enter 4-digit PIN',
                  colorScheme: colorScheme,
                  obscureText: _obscureCurrentPin,
                  onToggleObscure: () {
                    setState(() {
                      _obscureCurrentPin = !_obscureCurrentPin;
                    });
                  },
                  autofocus: true,
                  isCompact: isLandscape,
                  textInputAction: TextInputAction.done,
                  onChanged: (val) {
                    if (val.trim().length == 4) {
                      _handleSubmit();
                    }
                  },
                  onSubmitted: (_) => _handleSubmit(),
                ),
              ] else if (widget.mode == ParentalPinDialogMode.setPin) ...[
                _buildPinField(
                  controller: _newPinController,
                  focusNode: _newPinFocus,
                  label: 'Create 4-digit PIN',
                  colorScheme: colorScheme,
                  obscureText: _obscureNewPin,
                  onToggleObscure: () {
                    setState(() {
                      _obscureNewPin = !_obscureNewPin;
                    });
                  },
                  autofocus: true,
                  isCompact: isLandscape,
                  textInputAction: TextInputAction.next,
                  onChanged: (val) {
                    if (val.trim().length == 4) {
                      _confirmPinFocus.requestFocus();
                    }
                  },
                  onSubmitted: (_) => _confirmPinFocus.requestFocus(),
                ),
                SizedBox(height: isLandscape ? 4 : AppSpacing.sm),
                _buildPinField(
                  controller: _confirmPinController,
                  focusNode: _confirmPinFocus,
                  label: 'Confirm 4-digit PIN',
                  colorScheme: colorScheme,
                  obscureText: _obscureConfirmPin,
                  onToggleObscure: () {
                    setState(() {
                      _obscureConfirmPin = !_obscureConfirmPin;
                    });
                  },
                  isCompact: isLandscape,
                  textInputAction: TextInputAction.done,
                  onChanged: (val) {
                    if (val.trim().length == 4 &&
                        val.trim() == _newPinController.text.trim()) {
                      _handleSubmit();
                    }
                  },
                  onSubmitted: (_) => _handleSubmit(),
                ),
              ] else if (widget.mode == ParentalPinDialogMode.changePin) ...[
                _buildPinField(
                  controller: _currentPinController,
                  focusNode: _currentPinFocus,
                  label: 'Current 4-digit PIN',
                  colorScheme: colorScheme,
                  obscureText: _obscureCurrentPin,
                  onToggleObscure: () {
                    setState(() {
                      _obscureCurrentPin = !_obscureCurrentPin;
                    });
                  },
                  autofocus: true,
                  isCompact: isLandscape,
                  textInputAction: TextInputAction.next,
                  onChanged: (val) {
                    if (val.trim().length == 4) {
                      _newPinFocus.requestFocus();
                    }
                  },
                  onSubmitted: (_) => _newPinFocus.requestFocus(),
                ),
                SizedBox(height: isLandscape ? 4 : AppSpacing.sm),
                _buildPinField(
                  controller: _newPinController,
                  focusNode: _newPinFocus,
                  label: 'New 4-digit PIN',
                  colorScheme: colorScheme,
                  obscureText: _obscureNewPin,
                  onToggleObscure: () {
                    setState(() {
                      _obscureNewPin = !_obscureNewPin;
                    });
                  },
                  isCompact: isLandscape,
                  textInputAction: TextInputAction.next,
                  onChanged: (val) {
                    if (val.trim().length == 4) {
                      _confirmPinFocus.requestFocus();
                    }
                  },
                  onSubmitted: (_) => _confirmPinFocus.requestFocus(),
                ),
                SizedBox(height: isLandscape ? 4 : AppSpacing.sm),
                _buildPinField(
                  controller: _confirmPinController,
                  focusNode: _confirmPinFocus,
                  label: 'Confirm New 4-digit PIN',
                  colorScheme: colorScheme,
                  obscureText: _obscureConfirmPin,
                  onToggleObscure: () {
                    setState(() {
                      _obscureConfirmPin = !_obscureConfirmPin;
                    });
                  },
                  isCompact: isLandscape,
                  textInputAction: TextInputAction.done,
                  onChanged: (val) {
                    if (val.trim().length == 4 &&
                        val.trim() == _newPinController.text.trim()) {
                      _handleSubmit();
                    }
                  },
                  onSubmitted: (_) => _handleSubmit(),
                ),
              ],
              if (_errorMessage != null) ...[
                SizedBox(height: isLandscape ? 4 : AppSpacing.sm),
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
              SizedBox(height: isLandscape ? 8 : 16),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: 4.0,
                children: [
                  TextButton(
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.of(context).maybePop(false),
                    child: const Text('Cancel'),
                  ),
                  TvFocusable(
                    borderRadius: AppRadius.medium,
                    onTap: _isProcessing ? null : _handleSubmit,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
