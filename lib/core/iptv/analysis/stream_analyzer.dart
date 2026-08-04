import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:stream_hub/core/iptv/models/stream_analysis.dart';
import 'package:stream_hub/core/iptv/models/stream_protocol.dart';
import 'package:stream_hub/core/network/doh_http_client.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/stream_probe.dart';

/// Analyzes a stream's technical characteristics: codec, container,
/// resolution, frame rate, bitrate, audio, language, and DRM.
///
/// For adaptive protocols (HLS/DASH) the manifest is fetched (bounded) and
/// parsed to extract the variant ladder. For progressive streams the container
/// is derived from the URL extension and/or probe content type.
class StreamAnalyzer {
  static const int _maxManifestBytes = 512 * 1024;

  const StreamAnalyzer();

  /// Analyzes [session]. When [probe] is supplied its content type is used.
  /// [fetchManifest] controls whether HLS/DASH manifests are downloaded.
  Future<StreamAnalysis> analyze(
    PlayableSession session, {
    HttpProbeResult? probe,
    bool fetchManifest = true,
  }) async {
    final protocol = StreamProtocol.fromUrl(session.streamUrl);
    final container = _containerFrom(
      protocol,
      probe?.contentType,
      session.streamUrl,
    );
    final notes = <String>[];

    if (protocol == StreamProtocol.hls && fetchManifest) {
      try {
        final body = await _fetchBounded(
          session.streamUrl,
          headers: session.headers,
          timeout: session.networkTimeout,
        );
        if (body != null) {
          return _parseHls(body, container, session);
        }
        notes.add('Manifest fetch produced no body.');
      } catch (e) {
        notes.add('Manifest fetch failed: $e');
      }
    } else if (protocol == StreamProtocol.dash && fetchManifest) {
      try {
        final body = await _fetchBounded(
          session.streamUrl,
          headers: session.headers,
          timeout: session.networkTimeout,
        );
        if (body != null) {
          return _parseDash(body, container, session);
        }
        notes.add('MPD fetch produced no body.');
      } catch (e) {
        notes.add('MPD fetch failed: $e');
      }
    }

    return StreamAnalysis(
      container: container,
      drmScheme: session.drmInformation?.scheme,
      notes: notes,
    );
  }

  StreamAnalysis _parseHls(
    String manifest,
    String? container,
    PlayableSession session,
  ) {
    final variants = <_HlsVariant>[];
    var totalSegments = 0;
    var segmentSeconds = 0.0;
    var hasAesKey = false;

    for (final line in const LineSplitter().convert(manifest)) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#EXT-X-STREAM-INF')) {
        final variant = _HlsVariant.fromAttributeLine(trimmed);
        if (variant != null) variants.add(variant);
      } else if (trimmed.startsWith('#EXTINF:')) {
        final duration = double.tryParse(
          trimmed.replaceFirst('#EXTINF:', '').split(',')[0],
        );
        if (duration != null && duration > 0) {
          segmentSeconds += duration;
          totalSegments++;
        }
      } else if (trimmed.startsWith('#EXT-X-KEY:') &&
          trimmed.contains('AES-128')) {
        hasAesKey = true;
      }
    }

    _HlsVariant best = variants.isEmpty
        ? _HlsVariant.empty
        : variants.reduce(
            (a, b) => (b.bandwidth ?? 0) > (a.bandwidth ?? 0) ? b : a,
          );

    final double? avgSegmentDuration;
    if (totalSegments > 0) {
      avgSegmentDuration = double.parse(
        (segmentSeconds / totalSegments).toStringAsFixed(2),
      );
    } else {
      avgSegmentDuration = null;
    }

    return StreamAnalysis(
      container: container ?? 'mpegts',
      videoCodec: best.codecs?.isNotEmpty == true ? best.codecs!.first : null,
      resolution: best.width != null || best.height != null
          ? StreamResolutionInfo(width: best.width, height: best.height)
          : null,
      videoBitrate: best.bandwidth,
      variantCount: variants.length,
      maxBandwidth: variants.fold<int?>(
        0,
        (max, v) => (v.bandwidth ?? 0) > (max ?? 0) ? v.bandwidth : max,
      ),
      segmentDurationSeconds: avgSegmentDuration,
      drmScheme: hasAesKey ? 'AES-128' : session.drmInformation?.scheme,
      notes: [
        if (totalSegments > 0)
          '$totalSegments segments (avg ${avgSegmentDuration}s)',
        if (hasAesKey) 'AES-128 segment encryption detected',
      ],
    );
  }

  StreamAnalysis _parseDash(
    String mpd,
    String? container,
    PlayableSession session,
  ) {
    final reps = RegExp(
      r'<Representation\b[^>]*\b(?:width="(\d+)")?\s*\b(?:height="(\d+)")?\s*\b(?:bandwidth="(\d+)")?\s*\b(?:frameRate="([^"]*)")?\s*\b(?:codecs="([^"]*)")?',
    );
    var maxBandwidth = 0;
    int? width;
    int? height;
    double? frameRate;
    String? codecs;
    var count = 0;

    for (final match in reps.allMatches(mpd)) {
      count++;
      final w = int.tryParse(match.group(1) ?? '');
      final h = int.tryParse(match.group(2) ?? '');
      final bw = int.tryParse(match.group(3) ?? '');
      final fr = double.tryParse(match.group(4) ?? '');
      final co = match.group(5);
      if ((w ?? 0) > (width ?? 0)) width = w;
      if ((h ?? 0) > (height ?? 0)) height = h;
      if ((bw ?? 0) > maxBandwidth) maxBandwidth = bw ?? 0;
      if (fr != null && frameRate == null) frameRate = fr;
      if (co != null && codecs == null) codecs = co;
    }

    final drmMatch = RegExp(
      r'schemeIdUri="urn:uuid:([a-fA-F0-9-]+)"',
    ).firstMatch(mpd);
    final drmScheme = drmMatch != null ? 'DRM:${drmMatch.group(1)}' : null;

    return StreamAnalysis(
      container: container ?? 'mp4',
      videoCodec: codecs?.split(',')[0],
      resolution: width != null || height != null
          ? StreamResolutionInfo(width: width, height: height)
          : null,
      frameRate: frameRate,
      videoBitrate: maxBandwidth > 0 ? maxBandwidth : null,
      variantCount: count,
      maxBandwidth: maxBandwidth > 0 ? maxBandwidth : null,
      drmScheme: drmScheme ?? session.drmInformation?.scheme,
      notes: [
        if (count == 0) 'No Representations parsed from MPD.',
      ],
    );
  }

  String? _containerFrom(
    StreamProtocol protocol,
    String? mimeType,
    String url,
  ) {
    if (mimeType != null) {
      final lower = mimeType.toLowerCase();
      if (lower.contains('mp4')) return 'mp4';
      if (lower.contains('matroska')) return 'matroska';
      if (lower.contains('mpeg')) return 'mpegts';
      if (lower.contains('mpegurl')) return 'hls';
      if (lower.contains('dash')) return 'dash';
    }
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return 'hls';
    if (lower.contains('.mpd')) return 'dash';
    if (lower.contains('.mp4')) return 'mp4';
    if (lower.contains('.mkv')) return 'matroska';
    if (lower.contains('.ts')) return 'mpegts';
    switch (protocol) {
      case StreamProtocol.rtsp:
        return 'rtsp';
      case StreamProtocol.rtmp:
      case StreamProtocol.rtmps:
        return 'flv';
      case StreamProtocol.udp:
      case StreamProtocol.rtp:
        return 'mpegts';
      default:
        return null;
    }
  }

  Future<String?> _fetchBounded(
    String url, {
    required Map<String, String> headers,
    required Duration timeout,
  }) async {
    final client = createDohAwareHttpClient();
    try {
      client.connectionTimeout = timeout;
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(timeout);
      headers.forEach(request.headers.set);
      request.followRedirects = true;
      request.maxRedirects = 5;
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final builder = BytesBuilder();
      await for (final chunk in response.timeout(timeout)) {
        builder.add(chunk);
        if (builder.length > _maxManifestBytes) break;
      }
      return String.fromCharCodes(builder.takeBytes());
    } finally {
      client.close(force: true);
    }
  }
}

class _HlsVariant {
  final int? bandwidth;
  final int? width;
  final int? height;
  final List<String>? codecs;

  const _HlsVariant({
    this.bandwidth,
    this.width,
    this.height,
    this.codecs,
  });

  static const empty = _HlsVariant();

  static _HlsVariant? fromAttributeLine(String line) {
    final attributes = line.replaceFirst('#EXT-X-STREAM-INF:', '');
    final bandwidth = RegExp(r'BANDWIDTH=(\d+)').firstMatch(attributes);
    final resolution = RegExp(
      r'RESOLUTION=(\d+)x(\d+)',
    ).firstMatch(attributes);
    final codecsMatch = RegExp(
      r'CODECS="([^"]*)"',
    ).firstMatch(attributes);
    return _HlsVariant(
      bandwidth: bandwidth != null ? int.tryParse(bandwidth.group(1)!) : null,
      width: resolution != null ? int.tryParse(resolution.group(1)!) : null,
      height: resolution != null ? int.tryParse(resolution.group(2)!) : null,
      codecs: codecsMatch
          ?.group(1)
          ?.split(',')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList(),
    );
  }
}
