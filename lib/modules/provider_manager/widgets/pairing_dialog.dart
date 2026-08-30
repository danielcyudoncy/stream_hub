import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/helpers/platform_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/services/pairing_service.dart';
import '../../../modules/provider_manager/models/provider_enums.dart';
import '../../../shared/widgets/tv_focusable.dart';

class PairingDialog extends StatefulWidget {
  final ProviderType providerType;
  final void Function(Map<String, dynamic> formData)? onDataReceived;

  const PairingDialog({
    super.key,
    required this.providerType,
    this.onDataReceived,
  });

  static Future<void> show({
    required BuildContext context,
    required ProviderType providerType,
    required void Function(Map<String, dynamic> formData) onDataReceived,
  }) {
    final service = PairingService();
    if (!service.isAvailable) {
      Get.snackbar(
        'Unavailable',
        'Phone pairing requires Firebase to be available.',
        backgroundColor: Colors.red.withValues(alpha: 0.15),
        colorText: Colors.white,
      );
      return Future.value();
    }
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PairingDialog(
        providerType: providerType,
        onDataReceived: onDataReceived,
      ),
    );
  }

  @override
  State<PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<PairingDialog> {
  final PairingService _service = PairingService();
  StreamSubscription<Map<String, dynamic>?>? _dataSub;
  StreamSubscription<int>? _countdownSub;

  String? _code;
  String _pairingUrl = '';
  int _remainingSeconds = 300;
  bool _isListening = false;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _initPairing();
  }

  Future<void> _initPairing() async {
    try {
      final code = await _service.createPairing(widget.providerType);
      setState(() {
        _code = code;
        _pairingUrl = _service.getPairingUrl(code);
      });

      _dataSub = _service.watchFormData(code).listen((formData) {
        if (formData != null && !_isCompleted && mounted) {
          _isCompleted = true;
          widget.onDataReceived?.call(formData);
          Navigator.of(context).pop();
        }
      });

      _countdownSub = _service.watchCountdown(code).listen((seconds) {
        setState(() => _remainingSeconds = seconds);
        if (seconds <= 0 && mounted && !_isCompleted) {
          Navigator.of(context).pop();
        }
      });

      setState(() => _isListening = true);
    } catch (e) {
      String message = 'Failed to generate pairing code.';
      if (e.toString().contains('permission-denied') ||
          e.toString().contains('PERMISSION_DENIED') ||
          e.toString().contains('Missing or insufficient')) {
        message = 'Firestore permission denied. Please deploy firestore.rules.';
      }
      if (mounted) {
        Get.snackbar('Pairing Error', message);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _countdownSub?.cancel();
    _dataSub = null;
    _countdownSub = null;
    if (_code != null) {
      _service.deletePairing(_code!);
    }
    _service.dispose();
    super.dispose();
  }

  String get _formattedTime {
    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTV = PlatformHelper.isTV;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: isTV ? EdgeInsets.zero : const EdgeInsets.all(24.0),
        child: Container(
          width: isTV ? 540 : 420,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: _code == null
              ? const _LoadingState()
              : _PairingContent(
                  code: _code!,
                  pairingUrl: _pairingUrl,
                  formattedTime: _formattedTime,
                  isListening: _isListening,
                  isTV: isTV,
                  colorScheme: colorScheme,
                ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        AppSpacing.heightMD,
        Text(
          'Generating pairing code...',
          style: AppTypography.getBody(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PairingContent extends StatelessWidget {
  final String code;
  final String pairingUrl;
  final String formattedTime;
  final bool isListening;
  final bool isTV;
  final ColorScheme colorScheme;

  const _PairingContent({
    required this.code,
    required this.pairingUrl,
    required this.formattedTime,
    required this.isListening,
    required this.isTV,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Scan QR Code',
          style: AppTypography.getTitle(color: colorScheme.onSurface),
        ),
        AppSpacing.heightXS,
        Text(
          'Enter this code on your phone: $pairingUrl',
          style: AppTypography.getCaption(color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        AppSpacing.heightMD,
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: QrImageView(
            data: pairingUrl,
            version: QrVersions.auto,
            size: isTV ? 200 : 180,
            backgroundColor: Colors.white,
          ),
        ),
        AppSpacing.heightMD,
        SelectableText(
          code,
          style: AppTypography.getTitle(color: colorScheme.primary).copyWith(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
        AppSpacing.heightSM,
        Text(
          'Expires in: $formattedTime',
          style: AppTypography.getCaption(color: colorScheme.onSurfaceVariant),
        ),
        AppSpacing.heightXL,
        Text(
          'Point your phone camera at the QR code or go to\n$pairingUrl',
          style: AppTypography.getCaption(color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        AppSpacing.heightLG,
        TvFocusable(
          onTap: () {
            // Clean up the pairing before dismissing
            PairingService().deletePairing(code);
            Navigator.of(context).pop();
          },
          scale: 1.05,
          borderRadius: BorderRadius.circular(12),
          child: TextButton(
            onPressed: () {
              PairingService().deletePairing(code);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
              textStyle: AppTypography.getButton(color: colorScheme.onSurfaceVariant),
            ),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }
}
