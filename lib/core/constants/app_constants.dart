class AppConstants {
  // App Info
  static const String appName = 'StreamHub Pro';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';
  static const String developerName = 'StreamHub Pro Team';
  static const String appWebsite = 'https://streamhub-pro-website.web.app';
  static const String defaultUpdateManifestUrl = 'https://streamhub-pro-website.web.app/api/version.json';

  // Remote Config Keys for App Updates
  static const String keyRemoteConfigLatestVersionCode = 'latest_version_code';
  static const String keyRemoteConfigLatestVersionName = 'latest_version_name';
  static const String keyRemoteConfigMinSupportedVersionCode = 'min_supported_version_code';
  static const String keyRemoteConfigApkDownloadUrl = 'apk_download_url';
  static const String keyRemoteConfigReleaseNotes = 'release_notes';
  static const String keyRemoteConfigForceUpdate = 'force_update';

  // Hive Box Names
  static const String boxSettings = 'settings';
  static const String boxProviders = 'providers';
  static const String boxFavorites = 'favorites';
  static const String boxHistory = 'history';
  static const String boxProfiles = 'profiles';
  static const String boxDownloads = 'downloads';
  static const String boxWatchProgress = 'watch_progress';
  static const String boxRecentSearches = 'recent_searches';
  static const String boxCache = 'cache';
  static const String boxAuthSession = 'auth_session';
  static const String boxWatchlist = 'watchlist';

  // Settings Keys
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'language';
  static const String keyActiveProfileId = 'active_profile_id';
  static const String keyParentalLockEnabled = 'parental_lock_enabled';
  static const String keyParentalPin = 'parental_pin';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyLastCacheClear = 'last_cache_clear';
  static const String keyProviderOrder = 'provider_order';
  static const String keyLastOpenedScreen = 'last_opened_screen';
  static const String keyRecentSearches = 'recent_searches';

  // Routes
  static const String splashRoute = '/splash';
  static const String authRoute = '/auth';
  static const String homeRoute = '/home';
  static const String liveTVRoute = '/live-tv';
  static const String libraryRoute = '/library';
  static const String searchRoute = '/search';
  static const String settingsRoute = '/settings';
  static const String providerManagerRoute = '/provider-manager';

  // Timeouts & Network
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // Validation
  static const int minProviderNameLength = 2;
  static const int maxProviderNameLength = 64;
  static const int maxNotesLength = 500;
}
