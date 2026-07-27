class AppConstants {
  // App Info
  static const String appName = 'StreamHub Pro';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';

  // Hive Box Names
  static const String boxSettings = 'settings';
  static const String boxProviders = 'providers';
  static const String boxFavorites = 'favorites';
  static const String boxHistory = 'history';
  static const String boxProfiles = 'profiles';
  static const String boxDownloads = 'downloads';
  static const String boxWatchProgress = 'watch_progress';
  static const String boxRecentSearches = 'recent_searches';

  // Local Storage Settings Keys
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'language';
  static const String keyActiveProfileId = 'active_profile_id';
  static const String keyParentalLockEnabled = 'parental_lock_enabled';
  static const String keyParentalPin = 'parental_pin';

  // Timeouts & Network
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
