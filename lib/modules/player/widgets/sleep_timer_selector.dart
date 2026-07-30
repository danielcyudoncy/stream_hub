import 'dart:async';
import 'package:flutter/material.dart';
import 'package:stream_hub/core/theme/app_typography.dart';

class SleepTimerSelector extends StatefulWidget {
  final VoidCallback? onTimerSet;
  final VoidCallback? onTimerCancelled;

  const SleepTimerSelector({
    super.key,
    this.onTimerSet,
    this.onTimerCancelled,
  });

  @override
  State<SleepTimerSelector> createState() => _SleepTimerSelectorState();
}

class _SleepTimerSelectorState extends State<SleepTimerSelector> {
  Timer? _timer;
  int _remainingMinutes = 0;

  void _setTimer(int minutes) {
    _timer?.cancel();
    _remainingMinutes = minutes;
    _timer = Timer(Duration(minutes: minutes), () {
      widget.onTimerCancelled?.call();
    });
    widget.onTimerSet?.call();
    setState(() {});
  }

  void _cancelTimer() {
    _timer?.cancel();
    _remainingMinutes = 0;
    widget.onTimerCancelled?.call();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final durations = const [15, 30, 45, 60, 90, 120];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_remainingMinutes > 0)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Sleeping in $_remainingMinutes min',
              style: AppTypography.getBody(color: theme.colorScheme.onSurface),
            ),
          ),
        ...durations.map(
          (min) => ListTile(
            title: Text('$min minutes',
                style:
                    AppTypography.getBody(color: theme.colorScheme.onSurface)),
            onTap: () => _setTimer(min),
          ),
        ),
        ListTile(
          title: Text('Cancel',
              style: AppTypography.getBody(color: theme.colorScheme.error)),
          onTap: _cancelTimer,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
