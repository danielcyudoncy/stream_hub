// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';

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
    final colorScheme = theme.colorScheme;
    final currentId = (selectedTrackId ?? 'no').trim().toLowerCase();
    final isOff = currentId == 'no' ||
        currentId == 'none' ||
        currentId == '-1' ||
        currentId.isEmpty;
    final isAuto = currentId == 'auto';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.subtitles_rounded, color: colorScheme.primary, size: 22),
                AppSpacing.widthSM,
                Text(
                  'Subtitles',
                  style: AppTypography.getTitle(color: colorScheme.onSurface).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (tracks.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${tracks.length} Available',
                      style: AppTypography.getCaption(color: colorScheme.primary).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            AppSpacing.heightMD,
            _TrackOptionTile(
              title: 'Off',
              subtitle: 'Disable subtitles',
              isSelected: isOff,
              icon: Icons.subtitles_off_outlined,
              onTap: () {
                onSelected('no');
                onDisabled?.call();
              },
            ),
            _TrackOptionTile(
              title: 'Auto',
              subtitle: 'Select default or English track',
              isSelected: isAuto,
              icon: Icons.auto_awesome_rounded,
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
                  (!isOff && !isAuto && (currentId == idLower || currentId == label.toLowerCase()));

              return _TrackOptionTile(
                title: label,
                subtitle: language.isNotEmpty && language != 'und' ? 'Language: ${language.toUpperCase()}' : null,
                isSelected: isMatch,
                icon: Icons.closed_caption_rounded,
                onTap: () => onSelected(id),
              );
            }),
            AppSpacing.heightMD,
          ],
        ),
      ),
    );
  }
}

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
    final colorScheme = theme.colorScheme;
    final currentId = (selectedTrackId ?? 'auto').trim().toLowerCase();
    final isAuto = currentId == 'auto' || currentId.isEmpty;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.audiotrack_rounded, color: colorScheme.primary, size: 22),
                AppSpacing.widthSM,
                Text(
                  'Audio Tracks',
                  style: AppTypography.getTitle(color: colorScheme.onSurface).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (tracks.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${tracks.length} Available',
                      style: AppTypography.getCaption(color: colorScheme.primary).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            AppSpacing.heightMD,
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
                subtitle: language.isNotEmpty && language != 'und' ? 'Language: ${language.toUpperCase()}' : null,
                isSelected: isMatch,
                icon: Icons.volume_up_rounded,
                onTap: () => onSelected(id),
              );
            }),
            AppSpacing.heightMD,
          ],
        ),
      ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.15)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.15),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
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
      ),
    );
  }
}
