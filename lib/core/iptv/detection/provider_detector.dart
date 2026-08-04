import 'package:stream_hub/core/iptv/models/provider_detection.dart';

/// The input inspected by the [ProviderDetector].
class ProviderInput {
  /// Remote URL or local file path.
  final String? url;

  /// Inline content (only the leading bytes are required for detection).
  final String? content;

  const ProviderInput({this.url, this.content});

  bool get hasUrl => url != null && url!.isNotEmpty;
  bool get hasContent => content != null && content!.isNotEmpty;
}

/// Internal result of provider kind detection.
class _KindResult {
  final DetectedProviderKind kind;
  final double confidence;
  final List<String> signals;
  final List<String> warnings;

  const _KindResult({
    required this.kind,
    required this.confidence,
    required this.signals,
    required this.warnings,
  });
}

/// Automatically detects the provider kind, transport, and compression of an
/// IPTV source.
///
/// Supports plain M3U playlists, Xtream playlists/API, Stalker / MAG portals,
/// XMLTV guides, local playlists, remote playlists over HTTP/HTTPS, and
/// ZIP/GZIP wrapped payloads. Detection is evidence-based: every matched signal
/// is recorded so diagnostics can explain the decision.
class ProviderDetector {
  /// Magic bytes for GZIP (`\x1f\x8b`).
  static const gzipMagic = '\u001f\u008b';

  /// Magic bytes for a ZIP archive (`PK\x03\x04`).
  static const zipMagic = 'PK\u0003\u0004';

  /// Detects the provider characteristics from a URL and/or content sample.
  ProviderDetectionResult detect(ProviderInput input) {
    final signals = <String>[];
    final warnings = <String>[];

    final transport = _detectTransport(input);
    final compression = _detectCompression(input);
    final url = input.hasUrl ? input.url!.trim() : null;
    final content = input.hasContent ? input.content! : null;

    var kind = DetectedProviderKind.unknown;
    var confidence = 0.0;

    final sample = content ?? url ?? '';
    if (sample.isNotEmpty) {
      final result = _detectKind(sample, url: url);
      kind = result.kind;
      confidence = result.confidence;
      signals.addAll(result.signals);
      warnings.addAll(result.warnings);
    }

    return ProviderDetectionResult(
      providerKind: kind,
      transportKind: transport,
      compressionKind: compression,
      confidence: confidence,
      matchedSignals: signals,
      warnings: warnings,
      inspectedSource: _redact(sample),
      sourceUrl: url,
    );
  }

  _KindResult _detectKind(
    String sample, {
    String? url,
  }) {
    final signals = <String>[];
    final warnings = <String>[];
    final lowerUrl = (url ?? '').toLowerCase();
    final lowerSample = sample.toLowerCase();

    // --- Stalker / MAG portal ---
    if (lowerUrl.contains('/server/load.php') ||
        lowerUrl.contains('/stalker_portal/server/load.php') ||
        lowerUrl.contains('/portal.php') ||
        lowerUrl.contains('?mac=') ||
        RegExp(r'[?&]mac=[0-9a-f:]+').hasMatch(lowerUrl)) {
      signals.add('Stalker portal path (load.php / portal.php) matched');
      return _KindResult(
        kind: DetectedProviderKind.stalker,
        confidence: 1.0,
        signals: signals,
        warnings: warnings,
      );
    }

    // --- Xtream Codes API ---
    if (lowerUrl.contains('player_api.php') ||
        lowerUrl.contains('get.php?username=') ||
        lowerUrl.contains('xmltv.php?username=')) {
      signals.add('Xtream API endpoint (player_api.php / get.php / xmltv.php)');
      return _KindResult(
        kind: DetectedProviderKind.xtream,
        confidence: 1.0,
        signals: signals,
        warnings: warnings,
      );
    }
    final xtreamPorts = {'80', '443', '8080', '8081', '8888', '25461', '2095', '2053', '8805', '8325', '28082', '2096', '2082', '8443'};
    final uri = Uri.tryParse(url ?? '');
    if (uri != null &&
        uri.scheme.startsWith('http') &&
        uri.port != 0 &&
        xtreamPorts.contains('${uri.port}')) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length == 2 &&
          segments.every((s) => RegExp(r'^[A-Za-z0-9_\-\.]+$').hasMatch(s))) {
        signals.add('Xtream server layout (host:port/user/pass)');
        return _KindResult(
          kind: DetectedProviderKind.xtream,
          confidence: 0.9,
          signals: signals,
          warnings: warnings,
        );
      }
    }

    // --- XMLTV guide ---
    if (lowerSample.contains('<?xml') &&
        (lowerSample.contains('<tv ') ||
            lowerSample.contains('<programme') ||
            lowerSample.contains('<channel'))) {
      signals.add('XML declaration with TV/programme elements');
      return _KindResult(
        kind: DetectedProviderKind.xmltv,
        confidence: 0.95,
        signals: signals,
        warnings: warnings,
      );
    }
    if (lowerUrl.endsWith('.xml') ||
        lowerUrl.endsWith('.xml.gz') ||
        lowerUrl.contains('xmltv')) {
      signals.add('Guide URL suffix (.xml / .xml.gz)');
      return _KindResult(
        kind: DetectedProviderKind.xmltv,
        confidence: 0.8,
        signals: signals,
        warnings: warnings,
      );
    }

    // --- M3U playlist ---
    if (lowerSample.startsWith('#extm3u')) {
      signals.add('#EXTM3U playlist header matched');
      return _KindResult(
        kind: DetectedProviderKind.m3u,
        confidence: 1.0,
        signals: signals,
        warnings: warnings,
      );
    }
    if (lowerUrl.endsWith('.m3u') ||
        (lowerUrl.endsWith('.m3u8') && !lowerSample.contains('#extm3u'))) {
      signals.add('Playlist URL suffix (.m3u)');
      return _KindResult(
        kind: DetectedProviderKind.m3u,
        confidence: 0.75,
        signals: signals,
        warnings: warnings,
      );
    }

    // --- Local playlist ---
    if (url != null &&
        (url.startsWith('file://') ||
            (!RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false)
                .hasMatch(url) &&
                (url.contains('/') || url.contains('\\'))))) {
      signals.add('Local filesystem path or file:// scheme');
      return _KindResult(
        kind: DetectedProviderKind.local,
        confidence: 0.9,
        signals: signals,
        warnings: warnings,
      );
    }

    if (sample.isEmpty) {
      warnings.add('No content or URL provided to detect provider.');
    } else {
      warnings.add('Provider kind could not be determined from input.');
    }
    return _KindResult(
      kind: DetectedProviderKind.unknown,
      confidence: 0.0,
      signals: signals,
      warnings: warnings,
    );
  }

  SourceTransportKind _detectTransport(ProviderInput input) {
    final url = (input.url ?? '').trim().toLowerCase();
    if (url.startsWith('http://')) return SourceTransportKind.remoteHttp;
    if (url.startsWith('https://')) return SourceTransportKind.remoteHttps;
    if (url.startsWith('file://') ||
        (input.hasUrl && !RegExp(r'^[a-z][a-z0-9+.-]*://').hasMatch(url))) {
      return SourceTransportKind.localFile;
    }
    if (input.hasContent) return SourceTransportKind.inlineContent;
    return SourceTransportKind.inlineContent;
  }

  SourceCompressionKind _detectCompression(ProviderInput input) {
    final url = (input.url ?? '').trim().toLowerCase();
    if (url.endsWith('.gz') || url.endsWith('.gzip')) {
      return SourceCompressionKind.gzip;
    }
    if (url.endsWith('.zip')) return SourceCompressionKind.zip;
    final content = input.content;
    if (content != null && content.isNotEmpty) {
      if (content.startsWith(gzipMagic)) return SourceCompressionKind.gzip;
      if (content.startsWith(zipMagic)) return SourceCompressionKind.zip;
    }
    return SourceCompressionKind.none;
  }

  String _redact(String sample) {
    if (sample.length > 512) {
      return '${sample.substring(0, 512)}… (truncated)';
    }
    return sample;
  }
}
