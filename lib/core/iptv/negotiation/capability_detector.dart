import 'package:stream_hub/core/iptv/models/stream_analysis.dart';
import 'package:stream_hub/core/iptv/models/stream_protocol.dart';
import 'package:stream_hub/core/streaming/models/stream_capabilities.dart';

/// Detects the playback capabilities of a stream based on its protocol,
/// metadata, and technical analysis.
class CapabilityDetector {
  const CapabilityDetector();

  /// Builds a [StreamCapabilities] set for the given protocol and metadata.
  StreamCapabilities detect(
    StreamProtocol protocol, {
    Map<String, dynamic> metadata = const {},
    StreamAnalysis? analysis,
  }) {
    final catchup = metadata['catchup'];
    final isCatchup = catchup is Map && (catchup['supported'] ?? false) == true;

    final supportsQualitySelection = protocol.isAdaptive;
    final supportsSeeking = protocol.isSeekable || isCatchup;
    final supportsRecording = protocol.isLiveCapable;
    final supportsDownload =
        protocol == StreamProtocol.mp4 ||
        protocol == StreamProtocol.mkv ||
        (isCatchup && supportsSeeking);
    final supportsSubtitles = metadata['subtitles'] != null ||
        metadata['subtitleTracks'] != null;
    final supportsAudioTracks = metadata['audioTracks'] != null;
    final supportsResume = supportsSeeking && !isCatchup;

    return StreamCapabilities(
      supportsSeeking: supportsSeeking,
      supportsPause: true,
      supportsRecording: supportsRecording,
      supportsDownload: supportsDownload,
      supportsCatchup: isCatchup,
      supportsTimeshift: isCatchup,
      supportsSubtitles: supportsSubtitles,
      supportsAudioTracks: supportsAudioTracks,
      supportsQualitySelection: supportsQualitySelection,
      supportsResume: supportsResume,
    );
  }
}
