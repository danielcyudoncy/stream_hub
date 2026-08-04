import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Resolves hostnames over DNS-over-HTTPS (DoH) as a fallback for the
/// platform resolver.
///
/// Some networks, Android emulators, and "fluxing" IPTV CDN hosts fail the
/// normal `Socket.connect(host, ...)` host lookup even though the record is
/// published (e.g. the record briefly disappeared or the device DNS is stale).
/// This resolver queries public DoH endpoints so HTTP clients can still reach
/// the origin IP.
///
/// Lookups are cached with a short TTL and a single in-flight future is shared
/// per host to avoid duplicate queries.
class DohResolver {
  static const List<String> kDefaultEndpoints = [
    'https://cloudflare-dns.com/dns-query?name={host}&type={type}&ct=application/dns-json',
    'https://dns.google/resolve?name={host}&type={type}',
  ];

  static const Duration _kRequestTimeout = Duration(seconds: 4);
  static const int _kTypeA = 1;
  static const int _kTypeAaaa = 28;

  final List<String> _endpoints;
  final Duration _ttl;
  final HttpClient _client;

  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Future<List<InternetAddress>>> _inFlight = {};

  DohResolver({
    List<String> endpoints = kDefaultEndpoints,
    Duration ttl = const Duration(seconds: 60),
    HttpClient? client,
  })  : _endpoints = endpoints,
        _ttl = ttl,
        _client = client ?? _createDoHClient();

  static HttpClient _createDoHClient() {
    final client = HttpClient();
    client.findProxy = (uri) => 'DIRECT';
    client.connectionTimeout = _kRequestTimeout;
    return client;
  }

  /// Resolves [host] into addresses.
  ///
  /// Returns an empty list when the host cannot be resolved over DoH so
  /// callers can fall back to the platform resolver.
  Future<List<InternetAddress>> resolve(String host) async {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty) return const [];

    final literal = InternetAddress.tryParse(normalized);
    if (literal != null) return [literal];
    if (normalized == 'localhost') return const [];

    final cached = _cache[normalized];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.addresses;
    }

    final inFlight = _inFlight[normalized];
    if (inFlight != null) return inFlight;

    final future = _queryProviders(normalized).then(
      (addresses) {
        _cache[normalized] =
            _CacheEntry(addresses, DateTime.now().add(_ttl));
        _inFlight.remove(normalized);
        return addresses;
      },
    ).catchError((_) {
      _inFlight.remove(normalized);
      return const <InternetAddress>[];
    });

    _inFlight[normalized] = future;
    return future;
  }

  /// Drops the cached (and in-flight) state for [host].
  void clear(String host) {
    final normalized = host.trim().toLowerCase();
    _cache.remove(normalized);
    _inFlight.remove(normalized);
  }

  Future<List<InternetAddress>> _queryProviders(String host) async {
    for (final type in const [_kTypeA, _kTypeAaaa]) {
      final addresses = await _queryType(host, type);
      if (addresses.isNotEmpty) return addresses;
    }
    return const [];
  }

  Future<List<InternetAddress>> _queryType(String host, int type) async {
    for (final endpoint in _endpoints) {
      try {
        final uri = Uri.parse(
          endpoint
              .replaceAll('{host}', Uri.encodeQueryComponent(host))
              .replaceAll('{type}', '$type'),
        );

        final request = await _client.getUrl(uri).timeout(_kRequestTimeout);
        request.headers.set(HttpHeaders.acceptHeader, 'application/dns-json');
        request.headers.set(HttpHeaders.userAgentHeader, 'StreamHubPro/1.0');

        final response = await request.close().timeout(_kRequestTimeout);
        if (response.statusCode != HttpStatus.ok) continue;

        final bytes =
            await response.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
        final decoded = json.decode(utf8.decode(bytes));
        if (decoded is! Map) continue;

        final answers = decoded['Answer'];
        if (answers is! List) continue;

        final addresses = <InternetAddress>[];
        for (final answer in answers) {
          if (answer is! Map || answer['type'] != type) continue;
          final data = answer['data'] as String?;
          if (data == null) continue;
          final parsed = InternetAddress.tryParse(data);
          if (parsed != null) addresses.add(parsed);
        }

        if (addresses.isNotEmpty) return addresses;
      } catch (_) {
        // Try the next endpoint before falling back to the platform resolver.
      }
    }
    return const [];
  }

  void dispose() {
    _client.close(force: true);
    _cache.clear();
    _inFlight.clear();
  }
}

/// Creates an [HttpClient] that resolves hostnames through [DohResolver]
/// before falling back to the platform DNS.
///
/// The returned client keeps standard certificate validation intact: HTTPS
/// connections are wrapped with [SecureSocket.secure] using the original
/// hostname, so SNI and certificate checks are performed against the real host.
HttpClient createDohAwareHttpClient({DohResolver? resolver}) {
  final doh = resolver ?? DohResolver();
  final client = HttpClient();

  client.connectionFactory = (uri, proxyHost, proxyPort) async {
    if (proxyHost != null && proxyPort != null) {
      final socket = await Socket.connect(proxyHost, proxyPort);
      return ConnectionTask.fromSocket(Future.value(socket), socket.destroy);
    }

    final isSecure = uri.isScheme('https');
    final host = uri.host;
    final port = uri.port;

    // First try the standard platform resolver.
    SocketException? platformError;
    try {
      final socket = isSecure
          ? await SecureSocket.connect(host, port,
              timeout: const Duration(seconds: 5))
          : await Socket.connect(host, port,
              timeout: const Duration(seconds: 5));
      return ConnectionTask.fromSocket(Future.value(socket), socket.destroy);
    } on SocketException catch (e) {
      // Platform resolution/connection failed, attempt DoH fallback.
      platformError = e;
    } catch (_) {
      // Fall through to DoH
    }

    final addresses = await doh.resolve(host);
    if (addresses.isNotEmpty) {
      SocketException? lastError;
      for (final address in addresses) {
        try {
          final raw = await Socket.connect(address, port,
              timeout: const Duration(seconds: 5));
          if (!isSecure) {
            return ConnectionTask.fromSocket(Future.value(raw), raw.destroy);
          }
          final secure = await SecureSocket.secure(raw, host: host);
          return ConnectionTask.fromSocket(
              Future.value(secure), secure.destroy);
        } on SocketException catch (e) {
          lastError = e;
        }
      }
      if (lastError != null) {
        throw lastError;
      }
    }

    // DoH produced no usable addresses. Surface the original platform error
    // instead of re-attempting the (potentially long) platform lookup a second
    // time, which is what caused connections to hang on flaky resolvers.
    if (platformError != null) {
      throw platformError;
    }
    throw const SocketException('Could not resolve host');
  };

  return client;
}

class _CacheEntry {
  final List<InternetAddress> addresses;
  final DateTime expiresAt;

  _CacheEntry(this.addresses, this.expiresAt);
}
