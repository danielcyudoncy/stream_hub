import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../models/multi_view_layout_mode.dart';

/// Opens the TV-optimized layout selection dialog for Multi-View.
Future<MultiViewLayoutMode?> showMultiViewLayoutDialog(
  BuildContext context, {
  MultiViewLayoutMode? currentMode,
  ValueChanged<MultiViewLayoutMode>? onSelect,
}) {
  return showDialog<MultiViewLayoutMode>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (ctx) => MultiViewLayoutDialog(
      currentMode: currentMode ?? MultiViewLayoutMode.dualHorizontal,
      onSelect: (mode) {
        Navigator.of(ctx).pop(mode);
        onSelect?.call(mode);
      },
    ),
  );
}

class MultiViewLayoutDialog extends StatefulWidget {
  final MultiViewLayoutMode currentMode;
  final ValueChanged<MultiViewLayoutMode> onSelect;

  const MultiViewLayoutDialog({
    super.key,
    required this.currentMode,
    required this.onSelect,
  });

  @override
  State<MultiViewLayoutDialog> createState() => _MultiViewLayoutDialogState();
}

class _MultiViewLayoutDialogState extends State<MultiViewLayoutDialog> {
  MultiViewLayoutMode? _focusedMode;

  @override
  void initState() {
    super.initState();
    _focusedMode = widget.currentMode;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopOrTv =
        ResponsiveHelper.isTV(context) || ResponsiveHelper.isDesktop(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isDesktopOrTv ? 900.0 : 500.0,
            maxHeight: 560.0,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: AppRadius.large,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 32.0,
                spreadRadius: 8.0,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: AppRadius.small,
                      ),
                      child: const Icon(
                        Icons.dashboard_customize_rounded,
                        color: AppColors.primary,
                        size: 24.0,
                      ),
                    ),
                    AppSpacing.widthSM,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose Multi-View Layout',
                            style: AppTypography.getTitle(color: Colors.white).copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18.0,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            'Select how many screens you want to watch at the same time',
                            style: AppTypography.getBody(color: Colors.white60).copyWith(
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TvFocusable(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      scale: 1.1,
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.close, color: Colors.white70, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white10, height: 1),

              // Layout Cards
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: isDesktopOrTv
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: MultiViewLayoutMode.values.map((mode) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0),
                              child: _buildLayoutCard(mode),
                            ),
                          );
                        }).toList(),
                      )
                    : GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 10.0,
                        mainAxisSpacing: 10.0,
                        childAspectRatio: 1.05,
                        children: MultiViewLayoutMode.values.map((mode) {
                          return _buildLayoutCard(mode);
                        }).toList(),
                      ),
              ),

              // Footer with hints
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Use D-pad to highlight, press OK to select',
                      style: AppTypography.getCaption(color: Colors.white38),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayoutCard(MultiViewLayoutMode mode) {
    final isSelected = widget.currentMode == mode;
    final isFocused = _focusedMode == mode;

    return TvFocusable(
      autofocus: mode == widget.currentMode,
      onFocusChange: (focused) {
        if (focused && mounted) {
          setState(() => _focusedMode = mode);
        }
      },
      onTap: () => widget.onSelect(mode),
      borderRadius: AppRadius.medium,
      scale: 1.04,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isFocused
              ? const Color(0xFF21262D)
              : const Color(0xFF1A1F26),
          borderRadius: AppRadius.medium,
          border: Border.all(
            color: isFocused
                ? AppColors.primary
                : (isSelected ? AppColors.primary.withValues(alpha: 0.5) : Colors.white12),
            width: isFocused ? 2.2 : (isSelected ? 1.5 : 1.0),
          ),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 16.0,
                    spreadRadius: 2.0,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Wireframe Graphic
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: isFocused
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : Colors.white12,
                    width: 1.0,
                  ),
                ),
                padding: const EdgeInsets.all(4.0),
                child: _buildWireframeGraphic(mode, isFocused: isFocused),
              ),
            ),

            const SizedBox(height: 10.0),

            // Mode Label
            Text(
              _getShortTitle(mode),
              style: TextStyle(
                color: isFocused ? Colors.white : Colors.white70,
                fontSize: 13.0,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 2.0),

            // Subtitle Description
            Text(
              _getSubTitle(mode),
              style: TextStyle(
                color: isFocused ? AppColors.primary : Colors.white38,
                fontSize: 11.0,
                fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWireframeGraphic(MultiViewLayoutMode mode, {required bool isFocused}) {
    final activeFill = isFocused
        ? AppColors.primary.withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.10);
    final borderColor = isFocused
        ? AppColors.primary.withValues(alpha: 0.8)
        : Colors.white24;

    Widget slot(int number, {int flex = 1}) {
      return Expanded(
        flex: flex,
        child: Container(
          decoration: BoxDecoration(
            color: activeFill,
            borderRadius: BorderRadius.circular(3.0),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                color: isFocused ? Colors.white : Colors.white54,
                fontSize: 10.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    switch (mode) {
      case MultiViewLayoutMode.dualHorizontal:
        return Row(
          children: [
            slot(1),
            const SizedBox(width: 3.0),
            slot(2),
          ],
        );

      case MultiViewLayoutMode.dualVertical:
        return Column(
          children: [
            slot(1),
            const SizedBox(height: 3.0),
            slot(2),
          ],
        );

      case MultiViewLayoutMode.triple:
        return Row(
          children: [
            slot(1, flex: 2),
            const SizedBox(width: 3.0),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  slot(2),
                  const SizedBox(height: 3.0),
                  slot(3),
                ],
              ),
            ),
          ],
        );

      case MultiViewLayoutMode.quad:
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  slot(1),
                  const SizedBox(width: 3.0),
                  slot(2),
                ],
              ),
            ),
            const SizedBox(height: 3.0),
            Expanded(
              child: Row(
                children: [
                  slot(3),
                  const SizedBox(width: 3.0),
                  slot(4),
                ],
              ),
            ),
          ],
        );
    }
  }

  String _getShortTitle(MultiViewLayoutMode mode) {
    switch (mode) {
      case MultiViewLayoutMode.dualHorizontal:
        return 'Dual (Side-by-Side)';
      case MultiViewLayoutMode.dualVertical:
        return 'Dual (Stacked)';
      case MultiViewLayoutMode.triple:
        return 'Triple View';
      case MultiViewLayoutMode.quad:
        return 'Quad View';
    }
  }

  String _getSubTitle(MultiViewLayoutMode mode) {
    switch (mode) {
      case MultiViewLayoutMode.dualHorizontal:
        return '2 Screens · 50/50';
      case MultiViewLayoutMode.dualVertical:
        return '2 Screens · Top/Bottom';
      case MultiViewLayoutMode.triple:
        return '3 Screens · 1 Main + 2 Side';
      case MultiViewLayoutMode.quad:
        return '4 Screens · 2x2 Grid';
    }
  }
}
