import 'package:flutter/material.dart';
import '../../core/theme/app_icons.dart';

/// Represents a normalized movie category or genre bucket with associated
/// item count and display metadata.
@immutable
class MovieCategory {
  final String id;
  final String name;
  final int count;
  final IconData? icon;

  const MovieCategory({
    required this.id,
    required this.name,
    this.count = 0,
    this.icon,
  });

  /// Resolves an appropriate display icon for a category based on its name.
  static IconData defaultIconForName(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('action')) return Icons.bolt_outlined;
    if (lower.contains('adventure')) return Icons.explore_outlined;
    if (lower.contains('animat') || lower.contains('cartoon') || lower.contains('anime')) {
      return Icons.animation_outlined;
    }
    if (lower.contains('comedy') || lower.contains('humor')) {
      return Icons.sentiment_very_satisfied_outlined;
    }
    if (lower.contains('crime') || lower.contains('gangster') || lower.contains('detective')) {
      return Icons.local_police_outlined;
    }
    if (lower.contains('documentary') || lower.contains('docu')) {
      return Icons.videocam_outlined;
    }
    if (lower.contains('drama')) return Icons.theater_comedy_outlined;
    if (lower.contains('family') || lower.contains('kid') || lower.contains('child')) {
      return Icons.child_care_outlined;
    }
    if (lower.contains('fantasy')) return Icons.auto_awesome_outlined;
    if (lower.contains('history') || lower.contains('biograph')) {
      return Icons.history_edu_outlined;
    }
    if (lower.contains('horror')) return Icons.nightlight_round_outlined;
    if (lower.contains('music') || lower.contains('musical')) {
      return Icons.music_note_outlined;
    }
    if (lower.contains('mystery')) return Icons.search_outlined;
    if (lower.contains('romance') || lower.contains('romantic')) {
      return Icons.favorite_border_outlined;
    }
    if (lower.contains('sci-fi') || lower.contains('science fiction') || lower.contains('space')) {
      return Icons.rocket_launch_outlined;
    }
    if (lower.contains('thriller') || lower.contains('suspense')) {
      return Icons.visibility_outlined;
    }
    if (lower.contains('war') || lower.contains('military')) {
      return Icons.shield_outlined;
    }
    if (lower.contains('western')) return Icons.landscape_outlined;
    return AppIcons.movies;
  }

  MovieCategory copyWith({
    String? id,
    String? name,
    int? count,
    IconData? icon,
  }) {
    return MovieCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      count: count ?? this.count,
      icon: icon ?? this.icon,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MovieCategory &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          count == other.count &&
          icon == other.icon;

  @override
  int get hashCode => Object.hash(id, name, count, icon);

  @override
  String toString() => 'MovieCategory(id: $id, name: $name, count: $count)';
}
