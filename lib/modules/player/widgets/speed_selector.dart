import 'package:flutter/material.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/theme/app_typography.dart';

// ignore_for_file: deprecated_member_use

class SpeedSelector extends StatelessWidget {
  final PlaybackSpeed selected;
  final ValueChanged<PlaybackSpeed> onSelected;

  const SpeedSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: PlaybackSpeed.values
          .map(
            (speed) => RadioListTile<PlaybackSpeed>(
              title: Text(speed.label,
                  style: AppTypography.getBody(color: theme.colorScheme.onSurface)),
              value: speed,
              groupValue: selected,
              onChanged: (v) {
                if (v != null) onSelected(v);
              },
              dense: true,
            ),
          )
          .toList(),
    );
  }
}
