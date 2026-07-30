import 'package:flutter/material.dart';
import 'package:stream_hub/core/theme/app_typography.dart';

// ignore_for_file: deprecated_member_use

class AudioTrackSelector extends StatelessWidget {
  final List<dynamic> tracks;
  final String? selectedTrackId;
  final ValueChanged<String> onSelected;

  const AudioTrackSelector({
    super.key,
    required this.tracks,
    this.selectedTrackId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (tracks.isEmpty) {
      return Text(
        'No audio tracks available',
        style: AppTypography.getBody(color: theme.colorScheme.onSurfaceVariant),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: tracks
          .map((track) {
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
          })
          .toList(),
    );
  }
}
