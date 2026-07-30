import 'package:flutter/material.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/theme/app_typography.dart';

// ignore_for_file: deprecated_member_use

class AspectRatioSelector extends StatelessWidget {
  final AspectRatioMode selected;
  final ValueChanged<AspectRatioMode> onSelected;

  const AspectRatioSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: AspectRatioMode.values
          .map(
            (mode) => RadioListTile<AspectRatioMode>(
              title: Text(mode.displayName,
                  style: AppTypography.getBody(color: theme.colorScheme.onSurface)),
              value: mode,
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
