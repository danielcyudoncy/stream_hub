/// Utility class for generating profile-scoped Hive storage keys.
///
/// Strategy: Option A — key prefixing.
/// All data lives in the same shared Hive boxes but every key is prefixed
/// with the active profile ID so that each profile sees only its own data.
///
/// Key formats:
///   Favorites   →  "p_{profileId}:{itemId}"
///   Watch prog  →  "p_{profileId}/{itemId}"
///   History     →  "ph_{profileId}/{itemId}"
///
/// Backward-compatibility: when [profileId] is empty or null the helper
/// returns the bare [itemId], preserving existing data for single-profile
/// users who have not yet selected a profile.
class ProfileKeyHelper {
  ProfileKeyHelper._();

  static const String _favPrefix = 'p_';
  static const String _favSep = ':';
  static const String _watchSep = '/';
  static const String _histPrefix = 'ph_';

  // ─── Favorites ────────────────────────────────────────────────────────────

  /// Returns the Hive key for a favourite entry scoped to [profileId].
  static String favKey(String profileId, String itemId) {
    if (profileId.isEmpty) return itemId;
    return '$_favPrefix$profileId$_favSep$itemId';
  }

  /// Returns `true` when [key] belongs to [profileId] in the favorites box.
  static bool isFavKeyForProfile(String key, String profileId) {
    if (profileId.isEmpty) {
      // bare key — does not start with the prefix
      return !key.startsWith(_favPrefix);
    }
    return key.startsWith('$_favPrefix$profileId$_favSep');
  }

  /// Extracts the raw itemId from a favorites key.
  static String extractFavItemId(String key, String profileId) {
    if (profileId.isEmpty) return key;
    final expectedPrefix = '$_favPrefix$profileId$_favSep';
    if (key.startsWith(expectedPrefix)) {
      return key.substring(expectedPrefix.length);
    }
    return key;
  }

  // ─── Watch Progress ────────────────────────────────────────────────────────

  /// Returns the Hive key for a watch-progress entry scoped to [profileId].
  static String watchKey(String profileId, String itemId) {
    if (profileId.isEmpty) return itemId;
    return '$_favPrefix$profileId$_watchSep$itemId';
  }

  /// Returns `true` when [key] belongs to [profileId] in the sessions box.
  static bool isWatchKeyForProfile(String key, String profileId) {
    if (profileId.isEmpty) {
      return !key.startsWith(_favPrefix);
    }
    return key.startsWith('$_favPrefix$profileId$_watchSep');
  }

  /// Extracts the raw itemId from a watch-progress key.
  static String extractWatchItemId(String key, String profileId) {
    if (profileId.isEmpty) return key;
    final expectedPrefix = '$_favPrefix$profileId$_watchSep';
    if (key.startsWith(expectedPrefix)) {
      return key.substring(expectedPrefix.length);
    }
    return key;
  }

  // ─── History ───────────────────────────────────────────────────────────────

  /// Returns the Hive key for a history entry scoped to [profileId].
  static String histKey(String profileId, String itemId) {
    if (profileId.isEmpty) return itemId;
    return '$_histPrefix$profileId$_watchSep$itemId';
  }

  /// Returns `true` when [key] belongs to [profileId] in the history box.
  static bool isHistKeyForProfile(String key, String profileId) {
    if (profileId.isEmpty) {
      return !key.startsWith(_histPrefix);
    }
    return key.startsWith('$_histPrefix$profileId$_watchSep');
  }

  /// Extracts the raw itemId from a history key.
  static String extractHistItemId(String key, String profileId) {
    if (profileId.isEmpty) return key;
    final expectedPrefix = '$_histPrefix$profileId$_watchSep';
    if (key.startsWith(expectedPrefix)) {
      return key.substring(expectedPrefix.length);
    }
    return key;
  }
}
