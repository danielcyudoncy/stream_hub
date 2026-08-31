import 'dart:async';

import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/streaming/models/stream_probe.dart';
import 'package:stream_hub/core/streaming/network/dart_http_probe.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';

/// Probes Free Live TV streams for reachability and marks each channel as
/// working / not-working.
///
/// Reuses the existing [HttpProbe] abstraction ([DartHttpProbe] by default) so
/// the same DoH-aware, HEAD-then-GET probing used by the Stream Engine gates
/// the catalog — this layer only adds concurrency and result aggregation. A
/// channel is considered "working" when at least one of its stream URLs
/// answers with a success status (2xx) or a playable media content type.
///
/// The service is deliberately stateless and testable: inject a fake
/// [HttpProbe] to probe without a real network.
class FreeTvReachabilityService {
  final HttpProbe _probe;
  final LoggingService _logger;

  /// Media content-types considered playable even when a server answers with
  /// an unexpected status (e.g. some CDNs respond 200 with weird content).
  static const Set<String> _playableContentTypes = {
    'application/vnd.apple.mpegurl',
    'application/x-mpegurl',
    'application/mpegurl',
    'application/x-mpegURL',
    'video/mp2t',
    'video/mp4',
    'video/x-m4v',
    'video/webm',
    'application/dash+xml',
    'application/xml',
    'application/vnd.ms-sstr+xml',
  };

  FreeTvReachabilityService({
    HttpProbe? probe,
    LoggingService? logger,
  })  : _probe = probe ?? const DartHttpProbe(),
        _logger = logger ?? LoggingService();

  /// Probes every stream URL of [channel] and returns the channel with
  /// `isWorking` set. Returns true only if at least one URL is reachable.
  Future<FreeTvChannel> probeChannel(
    FreeTvChannel channel, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final urls = channel.streamUrls;
    if (urls.isEmpty) {
      return channel.copyWith(isWorking: false);
    }

    for (final url in urls) {
      final working = await _probeUrl(url, timeout);
      if (working) {
        return channel.copyWith(isWorking: true);
      }
    }
    return channel.copyWith(isWorking: false);
  }

  Future<bool> _probeUrl(String url, Duration timeout) async {
    try {
      final result = await _probe.probe(url, timeout: timeout);
      if (result.isSuccess) return true;
      // Some CDNs answer HEAD/GET with a non-2xx but still serve a playable
      // stream; treat media content-types as reachable.
      final contentType = result.contentType?.toLowerCase();
      return contentType != null && _playableContentTypes.contains(contentType);
    } on TimeoutException {
      return false;
    } on Exception {
      return false;
    }
  }

  /// Probes [channels] with a bounded concurrency pool and returns every
  /// channel with its `isWorking` state set (working or not, never null here).
  ///
  /// [onProbed] is invoked as each channel completes so a caller can persist
  /// results incrementally (offline-first: partial results survive an app
  /// restart mid-probe).
  Future<List<FreeTvChannel>> probeMany(
    List<FreeTvChannel> channels, {
    int concurrency = 16,
    Duration timeout = const Duration(seconds: 5),
    void Function(FreeTvChannel probed)? onProbed,
  }) async {
    if (channels.isEmpty) return const [];

    final results = <FreeTvChannel>[];
    var index = 0;

    Future<void> worker() async {
      while (index < channels.length) {
        final i = index++;
        final channel = channels[i];
        var probed = channel;
        try {
          probed = await probeChannel(channel, timeout: timeout);
        } catch (e) {
          _logger.warning(
            'Reachability probe failed for "${channel.name}": $e',
            tag: 'FreeTvReachabilityService',
          );
          probed = channel.copyWith(isWorking: false);
        }
        results.add(probed);
        onProbed?.call(probed);
      }
    }

    final workers = List<Future<void>>.generate(
      concurrency.clamp(1, channels.length),
      (_) => worker(),
    );
    await Future.wait(workers);

    // Preserve the original ordering via a lookup regardless of completion
    // order (probes complete out of order under a worker pool).
    final byId = {for (final c in results) c.id: c};
    return [for (final c in channels) byId[c.id] ?? c];
  }

  /// Convenience: probes [channels] and returns only the working subset.
  Future<List<FreeTvChannel>> filterWorking(
    List<FreeTvChannel> channels, {
    int concurrency = 16,
    Duration timeout = const Duration(seconds: 5),
    void Function(FreeTvChannel probed)? onProbed,
  }) async {
    final probed = await probeMany(
      channels,
      concurrency: concurrency,
      timeout: timeout,
      onProbed: onProbed,
    );
    return probed.where((c) => c.isWorking == true).toList();
  }
}
