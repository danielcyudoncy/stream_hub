import 'package:flutter/foundation.dart';

/// A single cookie with optional expiry.
@immutable
class CookieEntry {
  final String name;
  final String value;
  final DateTime? expiresAt;

  const CookieEntry({required this.name, required this.value, this.expiresAt});

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

/// Manages provider-scoped cookies: read, write, update, expire, and persist
/// cookies for every provider. Never logs cookie values.
class CookieManager {
  final Map<String, Map<String, CookieEntry>> _cookiesByProvider = {};

  /// Serializes cookies into the `Cookie` header format: `name=value; ...`.
  static String serializeCookies(Map<String, String> cookies) {
    return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  void setCookie(
    String providerId,
    String name,
    String value, {
    DateTime? expiresAt,
  }) {
    _providerMap(providerId)[name] = CookieEntry(
      name: name,
      value: value,
      expiresAt: expiresAt,
    );
  }

  void setCookies(
    String providerId,
    Map<String, String> cookies, {
    DateTime? expiresAt,
  }) {
    cookies.forEach((name, value) {
      setCookie(providerId, name, value, expiresAt: expiresAt);
    });
  }

  /// Restores previously persisted cookie entries for a provider.
  void restoreCookies(String providerId, List<CookieEntry> entries) {
    _providerMap(providerId).clear();
    for (final entry in entries) {
      if (!entry.isExpired) {
        _providerMap(providerId)[entry.name] = entry;
      }
    }
  }

  String? getCookie(String providerId, String name) {
    final entry = _providerMap(providerId)[name];
    if (entry == null) return null;
    if (entry.isExpired) {
      _providerMap(providerId).remove(name);
      return null;
    }
    return entry.value;
  }

  /// Returns non-expired cookies for the provider as a plain map.
  Map<String, String> getCookies(String providerId) {
    final map = _providerMap(providerId);
    final result = <String, String>{};
    final expired = <String>[];
    map.forEach((name, entry) {
      if (entry.isExpired) {
        expired.add(name);
      } else {
        result[name] = entry.value;
      }
    });
    for (final name in expired) {
      map.remove(name);
    }
    return result;
  }

  /// Returns the raw cookie entries (including metadata) for persistence.
  List<CookieEntry> entries(String providerId) {
    return List.unmodifiable(_providerMap(providerId).values);
  }

  void updateCookie(
    String providerId,
    String name,
    String value, {
    DateTime? expiresAt,
  }) {
    setCookie(providerId, name, value, expiresAt: expiresAt);
  }

  void removeCookie(String providerId, String name) {
    _providerMap(providerId).remove(name);
  }

  void removeExpired(String providerId) {
    final map = _providerMap(providerId);
    final expired = map.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();
    for (final name in expired) {
      map.remove(name);
    }
  }

  void removeExpiredAll() {
    for (final providerId in _cookiesByProvider.keys.toList()) {
      removeExpired(providerId);
    }
  }

  void clearProvider(String providerId) {
    _cookiesByProvider.remove(providerId);
  }

  void clearAll() {
    _cookiesByProvider.clear();
  }

  List<String> get providers => _cookiesByProvider.keys.toList();

  Map<String, CookieEntry> _providerMap(String providerId) {
    return _cookiesByProvider.putIfAbsent(
      providerId,
      () => <String, CookieEntry>{},
    );
  }
}
