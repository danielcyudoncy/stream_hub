import 'package:stream_hub/data/models/xmltv_models.dart';

class XMLTVHealthService {
  XMLTVHealthService();

  XMLTVHealth calculateHealth(XMLTVGuide guide, {
    bool? isConnected,
    int? latencyMs,
    bool? isAuthenticated,
    DateTime? lastSync,
    List<String>? errors,
  }) {
    return XMLTVHealth(
      isConnected: isConnected ?? false,
      latencyMs: latencyMs ?? 0,
      isAuthenticated: isAuthenticated ?? false,
      lastSync: lastSync,
      guideSizeBytes: guide.sizeBytes ?? 0,
      programCount: guide.programs.length,
      channelCount: guide.channels.length,
      matchedChannels: guide.channels.where((c) => c.iconUrl != null).length,
      unmatchedChannels: guide.channels.length - guide.channels.where((c) => c.iconUrl != null).length,
      guideVersion: guide.version,
      errors: errors ?? const [],
    );
  }
}