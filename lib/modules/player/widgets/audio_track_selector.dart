import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/tv_focusable.dart';

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
    final currentId = (selectedTrackId ?? 'auto').trim().toLowerCase();
    final isAuto = currentId == 'auto' || currentId.isEmpty;

    if (tracks.isEmpty) {
      return Text(
        'No audio tracks available',
        style: AppTypography.getBody(color: theme.colorScheme.onSurfaceVariant),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TrackOptionTile(
          title: 'Auto',
          subtitle: 'Default audio track',
          isSelected: isAuto,
          icon: Icons.auto_mode_rounded,
          onTap: () => onSelected('auto'),
        ),
        ...tracks.map((track) {
          String id = '';
          String label = '';
          String language = '';
          bool isTrackSelected = false;
          if (track is Map) {
            id = track['id']?.toString() ?? '';
            label = track['label']?.toString() ?? '';
            language = track['language']?.toString() ?? '';
            isTrackSelected = track['selected'] == true;
          } else {
            id = track.toString();
            label = id;
          }
          if (label.isEmpty) {
            label = language.isNotEmpty ? language.toUpperCase() : 'Track $id';
          } else if (language.isNotEmpty &&
              language != 'und' &&
              !label.toLowerCase().contains(language.toLowerCase())) {
            label = '$label (${language.toUpperCase()})';
          }

          final idLower = id.trim().toLowerCase();
          final isMatch = isTrackSelected ||
              (!isAuto && (currentId == idLower || currentId == label.toLowerCase()));

          return _TrackOptionTile(
            title: label,
            subtitle: language.isNotEmpty && language != 'und'
                ? 'Language: ${language.toUpperCase()}'
                : null,
            isSelected: isMatch,
            icon: Icons.volume_up_rounded,
            onTap: () => onSelected(id),
          );
        }),
      ],
    );
  }
}

class _TrackOptionTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const _TrackOptionTile({
    required this.title,
    this.subtitle,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TvFocusable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        scale: 1.02,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.15)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.15),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              AppSpacing.widthMD,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.getBody(
                        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                      ).copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTypography.getCaption(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: colorScheme.onPrimary,
                  ),
                )
              else
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
