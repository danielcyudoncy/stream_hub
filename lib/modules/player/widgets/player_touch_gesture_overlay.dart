import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum _DragType { none, brightness, volume }

/// A touch gesture overlay for video players providing:
/// - Left-side vertical drag: Adjusts brightness with real-time HUD and screen dimming.
/// - Right-side vertical drag: Adjusts volume with real-time HUD and audio control.
/// - Single tap: Toggles player controls.
/// - Double tap: Triggers play/pause or quick seek.
class PlayerTouchGestureOverlay extends StatefulWidget {
  final Widget? child;
  final Widget? controls;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final double initialBrightness;
  final double initialVolume;
  final ValueChanged<double>? onBrightnessChanged;
  final ValueChanged<double>? onVolumeChanged;
  final bool enableBrightness;
  final bool enableVolume;

  const PlayerTouchGestureOverlay({
    super.key,
    this.child,
    this.controls,
    this.onTap,
    this.onDoubleTap,
    this.initialBrightness = 1.0,
    this.initialVolume = 1.0,
    this.onBrightnessChanged,
    this.onVolumeChanged,
    this.enableBrightness = true,
    this.enableVolume = true,
  });

  @override
  State<PlayerTouchGestureOverlay> createState() =>
      _PlayerTouchGestureOverlayState();
}

class _PlayerTouchGestureOverlayState extends State<PlayerTouchGestureOverlay> {
  late double _brightness;
  late double _volume;

  _DragType _currentDrag = _DragType.none;
  double _dragStartY = 0.0;
  double _initialDragValue = 0.0;
  bool _showHud = false;
  Timer? _hudHideTimer;

  @override
  void initState() {
    super.initState();
    _brightness = widget.initialBrightness.clamp(0.05, 1.0);
    _volume = widget.initialVolume.clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(PlayerTouchGestureOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialVolume != widget.initialVolume &&
        _currentDrag != _DragType.volume) {
      _volume = widget.initialVolume.clamp(0.0, 1.0);
    }
  }

  @override
  void dispose() {
    _hudHideTimer?.cancel();
    super.dispose();
  }

  void _onVerticalDragStart(DragStartDetails details, BoxConstraints constraints) {
    _dragStartY = details.localPosition.dy;
    final isLeft = details.localPosition.dx < (constraints.maxWidth / 2);

    if (isLeft && widget.enableBrightness) {
      _currentDrag = _DragType.brightness;
      _initialDragValue = _brightness;
    } else if (!isLeft && widget.enableVolume) {
      _currentDrag = _DragType.volume;
      _initialDragValue = _volume;
    } else {
      _currentDrag = _DragType.none;
      return;
    }

    _hudHideTimer?.cancel();
    setState(() => _showHud = true);
  }

  void _onVerticalDragUpdate(
      DragUpdateDetails details, BoxConstraints constraints) {
    if (_currentDrag == _DragType.none) return;

    // A drag across 75% of the player height corresponds to full 0.0 -> 1.0 range
    final deltaY = _dragStartY - details.localPosition.dy;
    final sensitivityRange = (constraints.maxHeight * 0.75).clamp(100.0, 800.0);
    final deltaFraction = deltaY / sensitivityRange;

    if (_currentDrag == _DragType.brightness) {
      final newBrightness =
          (_initialDragValue + deltaFraction).clamp(0.05, 1.0);
      if ((newBrightness - _brightness).abs() > 0.005) {
        setState(() => _brightness = newBrightness);
        widget.onBrightnessChanged?.call(newBrightness);
      }
    } else if (_currentDrag == _DragType.volume) {
      final newVolume = (_initialDragValue + deltaFraction).clamp(0.0, 1.0);
      if ((newVolume - _volume).abs() > 0.005) {
        setState(() => _volume = newVolume);
        widget.onVolumeChanged?.call(newVolume);
      }
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _currentDrag = _DragType.none;
    _hudHideTimer?.cancel();
    _hudHideTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) {
        setState(() => _showHud = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dimOpacity = (1.0 - _brightness).clamp(0.0, 0.85);

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Underlying Player Content (Video)
            if (widget.child != null) widget.child!,

            // 2. Brightness Dimming Layer
            if (dimOpacity > 0.01)
              IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: dimOpacity),
                ),
              ),

            // 3. Touch Interceptor (Beneath controls so buttons remain fully interactive)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                onDoubleTap: widget.onDoubleTap,
                onVerticalDragStart: (details) =>
                    _onVerticalDragStart(details, constraints),
                onVerticalDragUpdate: (details) =>
                    _onVerticalDragUpdate(details, constraints),
                onVerticalDragEnd: _onVerticalDragEnd,
                onVerticalDragCancel: () => _onVerticalDragEnd(DragEndDetails()),
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),

            // 4. Overlaid Controls (Buttons, Top Bar, Bottom Bar)
            if (widget.controls != null) widget.controls!,

            // 5. Left HUD: Brightness Indicator
            if (_showHud && _currentDrag == _DragType.brightness)
              Positioned(
                left: 32.0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildHudCard(
                    icon: _getBrightnessIcon(_brightness),
                    percentage: (_brightness * 100).round(),
                    value: _brightness,
                    label: 'Brightness',
                    accentColor: const Color(0xFFFFB300),
                  ),
                ),
              ),

            // 6. Right HUD: Volume Indicator
            if (_showHud && _currentDrag == _DragType.volume)
              Positioned(
                right: 32.0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildHudCard(
                    icon: _getVolumeIcon(_volume),
                    percentage: (_volume * 100).round(),
                    value: _volume,
                    label: 'Volume',
                    accentColor: AppColors.primary,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHudCard({
    required IconData icon,
    required int percentage,
    required double value,
    required String label,
    required Color accentColor,
  }) {
    return AnimatedOpacity(
      opacity: _showHud ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: 68.0,
        height: 190.0,
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 18.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon
            Icon(
              icon,
              color: accentColor,
              size: 24.0,
            ),

            // Vertical Progress Bar
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Container(
                  width: 8.0,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      width: 8.0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            accentColor,
                            accentColor.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4.0),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.5),
                            blurRadius: 6.0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Percentage Text
            Text(
              '$percentage%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getBrightnessIcon(double value) {
    if (value > 0.66) return Icons.brightness_7_rounded;
    if (value > 0.33) return Icons.brightness_6_rounded;
    return Icons.brightness_5_rounded;
  }

  IconData _getVolumeIcon(double value) {
    if (value <= 0.001) return Icons.volume_off_rounded;
    if (value < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }
}
