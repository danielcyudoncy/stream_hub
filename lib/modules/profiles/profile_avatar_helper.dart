import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../data/models/profile_model.dart';

// ─── Preset avatar palette ─────────────────────────────────────────────────
// Each avatar is a (background-color, icon) pair. No external images needed.
const List<({Color color, IconData icon})> kAvatarPresets = [
  (color: Color(0xFF6750A4), icon: Icons.person_rounded),
  (color: Color(0xFF0077B6), icon: Icons.sports_esports_rounded),
  (color: Color(0xFF2D6A4F), icon: Icons.nature_rounded),
  (color: Color(0xFFC9184A), icon: Icons.favorite_rounded),
  (color: Color(0xFFE76F51), icon: Icons.local_fire_department_rounded),
  (color: Color(0xFF4895EF), icon: Icons.star_rounded),
  (color: Color(0xFF9B5DE5), icon: Icons.music_note_rounded),
  (color: Color(0xFF00B4D8), icon: Icons.movie_rounded),
  (color: Color(0xFF43AA8B), icon: Icons.travel_explore_rounded),
  (color: Color(0xFFFF6B6B), icon: Icons.bolt_rounded),
  (color: Color(0xFFFFB703), icon: Icons.emoji_nature_rounded),
  (color: Color(0xFF606C38), icon: Icons.sports_soccer_rounded),
];

/// Checks if a photo URL represents an external network image (e.g. Google avatar).
bool isNetworkAvatar(String? photoUrl) {
  if (photoUrl == null) return false;
  final trimmed = photoUrl.trim();
  return trimmed.startsWith('http://') || trimmed.startsWith('https://');
}

/// Derives an avatar preset index from a profile id / photo url
/// (treated as an "avatar code" that is just the preset index as a string).
int avatarIndexForProfile(ProfileModel? profile) {
  if (profile == null) return 0;
  final raw = profile.photoUrl ?? '';
  final parsed = int.tryParse(raw);
  if (parsed != null && parsed >= 0 && parsed < kAvatarPresets.length) {
    return parsed;
  }
  // Fall back: hash the profile id to a stable index.
  return profile.id.hashCode.abs() % kAvatarPresets.length;
}

/// A unified avatar widget that renders either an authenticated user's remote
/// avatar image (e.g. Google profile picture) with cached fallback, or one of
/// the preset theme avatars.
class ProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final ProfileModel? profile;
  final double radius;
  final double? iconSize;

  const ProfileAvatar({
    super.key,
    this.photoUrl,
    this.profile,
    this.radius = 16.0,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final photoToUse = (photoUrl != null && photoUrl!.trim().isNotEmpty)
        ? photoUrl!.trim()
        : (profile?.photoUrl?.trim() ?? '0');
    final idx = int.tryParse(photoToUse) ?? avatarIndexForProfile(profile);
    final preset = kAvatarPresets[idx.clamp(0, kAvatarPresets.length - 1)];
    final effectiveIconSize = iconSize ?? (radius * 0.875);

    if (isNetworkAvatar(photoToUse)) {
      return CachedNetworkImage(
        imageUrl: photoToUse,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: radius,
          backgroundColor: preset.color,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: preset.color,
          child: Icon(preset.icon, color: Colors.white, size: effectiveIconSize),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: preset.color,
          child: Icon(preset.icon, color: Colors.white, size: effectiveIconSize),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: preset.color,
      child: Icon(preset.icon, color: Colors.white, size: effectiveIconSize),
    );
  }
}
