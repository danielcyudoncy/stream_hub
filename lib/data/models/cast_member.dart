import '../../core/utils/image_url_formatter.dart';

class CastMember {
  final String name;
  final String? character;
  final String? profileUrl;

  const CastMember({
    required this.name,
    this.character,
    this.profileUrl,
  });

  factory CastMember.fromString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.contains(' as ')) {
      final parts = trimmed.split(' as ');
      return CastMember(
        name: parts.first.trim(),
        character: parts.sublist(1).join(' as ').trim(),
      );
    }
    final parenMatch = RegExp(r'^(.*?)\s*\((.*?)\)$').firstMatch(trimmed);
    if (parenMatch != null) {
      final name = parenMatch.group(1)?.trim() ?? '';
      final char = parenMatch.group(2)?.trim();
      if (name.isNotEmpty) {
        return CastMember(name: name, character: char);
      }
    }
    return CastMember(name: trimmed);
  }

  factory CastMember.fromMap(Map<dynamic, dynamic> map) {
    final rawProfile = map['profileUrl'] ??
        map['profile_url'] ??
        map['profile_path'] ??
        map['profilePath'] ??
        map['image'] ??
        map['photo'];
    return CastMember(
      name: map['name']?.toString() ?? map['actor']?.toString() ?? '',
      character: map['character']?.toString() ?? map['role']?.toString(),
      profileUrl: ImageUrlFormatter.format(rawProfile),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (character != null) 'character': character,
      if (profileUrl != null) 'profileUrl': profileUrl,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CastMember &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          character == other.character;

  @override
  int get hashCode => name.hashCode ^ character.hashCode;
}
