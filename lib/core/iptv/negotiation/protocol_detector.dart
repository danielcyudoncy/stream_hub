import 'package:stream_hub/core/iptv/models/stream_protocol.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/models/stream_probe.dart';

/// How the protocol was detected.
enum ProtocolDetectionMethod { url, mimeType, content, probe, streamType }

/// The outcome of protocol detection with the evidence that drove it.
class ProtocolDetection {
  final StreamProtocol protocol;
  final ProtocolDetectionMethod method;
  final List<String> signals;

  const ProtocolDetection({
    required this.protocol,
    required this.method,
    this.signals = const [],
  });
}

/// Automatically detects the transport protocol of a stream.
///
/// Detection order:
/// 1. Stream type (from the Stream Engine resolution).
/// 2. URL extension / scheme.
/// 3. MIME type (from a probe).
/// 4. Content sample (HLS manifest header, DASH XML root).
class ProtocolDetector {
  const ProtocolDetector();

  /// Detects the protocol from URL and stream type.
  ProtocolDetection fromUrl(String url, {StreamType? streamType}) {
    final signals = <String>[];

    if (streamType != null && streamType != StreamType.unknown) {
      final mapped = _fromStreamType(streamType);
      if (mapped != StreamProtocol.unknown) {
        signals.add('Mapped from stream type ${streamType.displayName}');
        return ProtocolDetection(
          protocol: mapped,
          method: ProtocolDetectionMethod.streamType,
          signals: signals,
        );
      }
    }

    final fromUrl = StreamProtocol.fromUrl(url);
    if (fromUrl != StreamProtocol.unknown) {
      signals.add('Detected from URL extension/scheme');
      return ProtocolDetection(
        protocol: fromUrl,
        method: ProtocolDetectionMethod.url,
        signals: signals,
      );
    }

    return const ProtocolDetection(
      protocol: StreamProtocol.unknown,
      method: ProtocolDetectionMethod.url,
    );
  }

  /// Refines a detection with MIME type and/or content sample.
  ProtocolDetection refine(
    ProtocolDetection initial, {
    String? mimeType,
    HttpProbeResult? probe,
    String? contentSample,
  }) {
    final signals = List<String>.from(initial.signals);
    var protocol = initial.protocol;

    if (probe != null && probe.contentType != null) {
      final fromMime = StreamProtocol.fromMimeType(probe.contentType);
      if (fromMime != StreamProtocol.unknown) {
        protocol = fromMime;
        signals.add('Detected from MIME type ${probe.contentType}');
        return ProtocolDetection(
          protocol: protocol,
          method: ProtocolDetectionMethod.probe,
          signals: signals,
        );
      }
    }

    if (mimeType != null && mimeType.isNotEmpty) {
      final fromMime = StreamProtocol.fromMimeType(mimeType);
      if (fromMime != StreamProtocol.unknown) {
        protocol = fromMime;
        signals.add('Detected from MIME type $mimeType');
        return ProtocolDetection(
          protocol: protocol,
          method: ProtocolDetectionMethod.mimeType,
          signals: signals,
        );
      }
    }

    if (contentSample != null && contentSample.isNotEmpty) {
      final fromContent = _fromContent(contentSample);
      if (fromContent != StreamProtocol.unknown) {
        protocol = fromContent;
        signals.add('Detected from content signature');
        return ProtocolDetection(
          protocol: protocol,
          method: ProtocolDetectionMethod.content,
          signals: signals,
        );
      }
    }

    return ProtocolDetection(
      protocol: protocol,
      method: initial.method,
      signals: signals,
    );
  }

  StreamProtocol _fromStreamType(StreamType type) {
    switch (type) {
      case StreamType.hls:
        return StreamProtocol.hls;
      case StreamType.httpLive:
        return StreamProtocol.http;
      case StreamType.httpsLive:
        return StreamProtocol.https;
      case StreamType.mpegTs:
        return StreamProtocol.mpegTs;
      case StreamType.dash:
        return StreamProtocol.dash;
      case StreamType.mp4:
        return StreamProtocol.mp4;
      case StreamType.mkv:
        return StreamProtocol.mkv;
      case StreamType.rtsp:
        return StreamProtocol.rtsp;
      case StreamType.rtmp:
        return StreamProtocol.rtmp;
      case StreamType.unknown:
        return StreamProtocol.unknown;
    }
  }

  StreamProtocol _fromContent(String sample) {
    final head = sample.trimLeft();
    if (head.startsWith('#EXTM3U')) return StreamProtocol.hls;
    if (head.startsWith('<?xml') && head.contains('<MPD')) {
      return StreamProtocol.dash;
    }
    return StreamProtocol.unknown;
  }
}
