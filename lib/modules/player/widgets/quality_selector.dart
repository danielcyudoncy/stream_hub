import 'package:flutter/material.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/theme/app_typography.dart';

// ignore_for_file: deprecated_member_use

class QualitySelector extends StatelessWidget {
  final PlayerQuality selected;
  final List<PlayerQuality> available;
  final ValueChanged<PlayerQuality> onSelected;

  const QualitySelector({
    super.key,
    required this.selected,
    required this.available,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: available
          .map(
            (q) => RadioListTile<PlayerQuality>(
              title: Text(q.displayName,
                  style: AppTypography.getBody(color: theme.colorScheme.onSurface)),
              value: q,
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
