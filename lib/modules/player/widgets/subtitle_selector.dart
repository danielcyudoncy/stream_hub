import 'package:flutter/material.dart';
import 'package:stream_hub/core/theme/app_typography.dart';

// ignore_for_file: deprecated_member_use

class SubtitleSelector extends StatelessWidget {
  final List<dynamic> tracks;
  final String? selectedTrackId;
  final ValueChanged<String> onSelected;
  final VoidCallback? onDisabled;

  const SubtitleSelector({
    super.key,
    required this.tracks,
    this.selectedTrackId,
    required this.onSelected,
    this.onDisabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RadioListTile<String>(
          title: Text('Off',
              style: AppTypography.getBody(color: theme.colorScheme.onSurface)),
          value: '',
          groupValue: selectedTrackId,
          onChanged: onDisabled == null
              ? null
              : (v) {
                  if (v != null) onSelected(v);
                },
          dense: true,
        ),
        ...tracks.map((track) {
          final id = track.toString();
          return RadioListTile<String>(
            title: Text(track.toString(),
                style: AppTypography.getBody(color: theme.colorScheme.onSurface)),
            value: id,
            groupValue: selectedTrackId,
            onChanged: (v) {
              if (v != null) onSelected(v);
            },
            dense: true,
          );
        }),
      ],
    );
  }
}
