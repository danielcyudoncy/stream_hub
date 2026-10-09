class AppUpdateInfo {
  final String latestVersion;
  final int buildNumber;
  final int minSupportedBuild;
  final String apkUrl;
  final List<String> releaseNotes;
  final bool forceUpdate;
  final int? fileSize;
  final String? sha256;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.buildNumber,
    this.minSupportedBuild = 0,
    required this.apkUrl,
    this.releaseNotes = const [],
    this.forceUpdate = false,
    this.fileSize,
    this.sha256,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['release_notes'] ?? json['releaseNotes'];
    final List<String> parsedNotes;
    if (rawNotes is List) {
      parsedNotes = rawNotes.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    } else if (rawNotes is String && rawNotes.trim().isNotEmpty) {
      parsedNotes = rawNotes
          .split('\n')
          .map((line) => line.replaceAll(RegExp(r'^[\s*\-•]+'), '').trim())
          .where((line) => line.isNotEmpty)
          .toList();
    } else {
      parsedNotes = const [];
    }

    return AppUpdateInfo(
      latestVersion: (json['latest_version'] ?? json['version'] ?? '').toString(),
      buildNumber: _parseInt(json['build_number'] ?? json['version_code'] ?? json['buildNumber']),
      minSupportedBuild: _parseInt(json['min_supported_build'] ?? json['min_version_code'] ?? json['minSupportedBuild']),
      apkUrl: (json['apk_url'] ?? json['download_url'] ?? json['apkUrl'] ?? '').toString(),
      releaseNotes: parsedNotes,
      forceUpdate: json['force_update'] == true || json['forceUpdate'] == true,
      fileSize: json['file_size'] is num ? (json['file_size'] as num).toInt() : null,
      sha256: json['sha256']?.toString(),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  Map<String, dynamic> toJson() => {
    'latest_version': latestVersion,
    'build_number': buildNumber,
    'min_supported_build': minSupportedBuild,
    'apk_url': apkUrl,
    'release_notes': releaseNotes,
    'force_update': forceUpdate,
    if (fileSize != null) 'file_size': fileSize,
    if (sha256 != null) 'sha256': sha256,
  };
}
