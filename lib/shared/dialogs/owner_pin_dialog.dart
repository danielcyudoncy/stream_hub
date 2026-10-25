import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/constants/app_constants.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

class OwnerPinDialog extends StatefulWidget {
  final String title;
  final String message;

  const OwnerPinDialog({
    super.key,
    this.title = '👑 Owner Master Verification',
    this.message = 'Enter the secret 4-digit Master PIN to verify app ownership.',
  });

  /// Displays the Owner PIN Dialog and returns [true] if the correct Master PIN was entered.
  static Future<bool> show({
    BuildContext? context,
    String title = '👑 Owner Master Verification',
    String message = 'Enter the secret 4-digit Master PIN to verify app ownership.',
  }) async {
    final ctx = context ?? Get.context;
    if (ctx == null) return false;
    final result = await showDialog<bool>(
      context: ctx,
      barrierDismissible: true,
      builder: (context) => OwnerPinDialog(
        title: title,
        message: message,
      ),
    );
    return result == true;
  }

  @override
  State<OwnerPinDialog> createState() => _OwnerPinDialogState();
}

class _OwnerPinDialogState extends State<OwnerPinDialog> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  String? _errorMessage;
  bool _obscurePin = true;

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  void _verifyPin() {
    final entered = _pinController.text.trim();
    if (entered.length < 4) {
      setState(() {
        _errorMessage = 'PIN must be at least 4 digits.';
      });
      return;
    }

    if (entered == AppConstants.ownerMasterPin) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN. Access denied.';
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.large,
        side: BorderSide(
          color: Colors.amber.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.amber, width: 2),
                ),
                child: const Icon(
                  Icons.vpn_key_rounded,
                  color: Colors.amber,
                  size: 28,
                ),
              ),
              AppSpacing.heightMD,
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: AppTypography.getTitle(
                  color: isDark ? Colors.white : Colors.black87,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
              AppSpacing.heightSM,
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: AppTypography.getCaption(
                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                ),
              ),
              AppSpacing.heightLG,
              TextField(
                controller: _pinController,
                focusNode: _pinFocusNode,
                autofocus: true,
                obscureText: _obscurePin,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  hintStyle: TextStyle(
                    fontSize: 24,
                    letterSpacing: 12,
                    color: isDark ? AppColors.textMuted : AppColors.lightTextSecondary,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF12121A)
                      : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.medium,
                    borderSide: BorderSide(
                      color: isDark ? AppColors.surfaceVariant : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: AppRadius.medium,
                    borderSide: BorderSide(
                      color: Colors.amber,
                      width: 2,
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePin
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePin = !_obscurePin;
                      });
                    },
                  ),
                ),
                onSubmitted: (_) => _verifyPin(),
              ),
              if (_errorMessage != null) ...[
                AppSpacing.heightSM,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              AppSpacing.heightLG,
              Row(
                children: [
                  Expanded(
                    child: TvFocusable(
                      borderRadius: AppRadius.medium,
                      onTap: () => Navigator.of(context).pop(false),
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.medium,
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TvFocusable(
                      borderRadius: AppRadius.medium,
                      onTap: _verifyPin,
                      child: ElevatedButton(
                        onPressed: _verifyPin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.medium,
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Verify PIN',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
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
