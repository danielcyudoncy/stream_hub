class Validators {
  static final RegExp _emailRegExp = RegExp(
    r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
  );

  static final RegExp _macRegExp = RegExp(
    r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$',
  );

  static bool isValidEmail(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    return _emailRegExp.hasMatch(email.trim());
  }

  static bool isValidPassword(String? password) {
    if (password == null) return false;
    // Minimum 6 characters
    return password.length >= 6;
  }

  static bool isValidUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final cleanUrl = url.trim();
    // Simple URI check
    try {
      final uri = Uri.parse(cleanUrl);
      return uri.hasScheme && uri.hasAuthority;
    } catch (_) {
      return false;
    }
  }

  /// Accepts a host with optional port and path, with or without a scheme.
  ///
  /// Xtream and Stalker portals are commonly distributed as schemeless
  /// addresses (e.g. `portal.example.com/c`); both providers normalize the
  /// address to `http://` internally, so the form must not reject them.
  static bool isValidServerUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    var cleanUrl = url.trim();
    if (!cleanUrl.contains('://')) cleanUrl = 'http://$cleanUrl';
    try {
      final uri = Uri.parse(cleanUrl);
      return uri.hasScheme && uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static bool isValidMacAddress(String? mac) {
    if (mac == null || mac.trim().isEmpty) return false;
    return _macRegExp.hasMatch(mac.trim());
  }
}
