import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String? icon;
  final String? description;
  final List<String> channelIds;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Category({
    required this.id,
    required this.name,
    this.icon,
    this.description,
    this.channelIds = const [],
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Category copyWith({
    String? id,
    String? name,
    String? icon,
    String? description,
    List<String>? channelIds,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      channelIds: channelIds ?? this.channelIds,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayName => name;

  int get channelCount => channelIds.length;
}