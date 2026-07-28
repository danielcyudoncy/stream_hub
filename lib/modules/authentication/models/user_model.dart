enum AuthProvider {
  email,
  google,
  anonymous,
  unknown;

  String get displayName {
    switch (this) {
      case AuthProvider.email:
        return 'Email & Password';
      case AuthProvider.google:
        return 'Google';
      case AuthProvider.anonymous:
        return 'Anonymous';
      case AuthProvider.unknown:
        return 'Unknown';
    }
  }
}

class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final AuthProvider provider;
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime lastLogin;
  final String language;
  final String themePreference;

  const UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.provider,
    this.emailVerified = false,
    required this.createdAt,
    required this.lastLogin,
    this.language = 'en',
    this.themePreference = 'system',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      provider: AuthProvider.values.firstWhere(
        (e) => e.name == json['provider'],
        orElse: () => AuthProvider.unknown,
      ),
      emailVerified: json['emailVerified'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLogin: DateTime.parse(json['lastLogin'] as String),
      language: json['language'] as String? ?? 'en',
      themePreference: json['themePreference'] as String? ?? 'system',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'provider': provider.name,
      'emailVerified': emailVerified,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin.toIso8601String(),
      'language': language,
      'themePreference': themePreference,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    AuthProvider? provider,
    bool? emailVerified,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? language,
    String? themePreference,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      provider: provider ?? this.provider,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      language: language ?? this.language,
      themePreference: themePreference ?? this.themePreference,
    );
  }
}
