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
