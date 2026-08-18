import 'dart:io';

/// Custom [HttpOverrides] that configures standard browser headers and
/// allows self-signed/expired SSL certificates common in IPTV panel servers.
class AppHttpOverrides extends HttpOverrides {
  static const String defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.userAgent = defaultUserAgent;
    client.badCertificateCallback = (cert, host, port) => true;
    return client;
  }
}
