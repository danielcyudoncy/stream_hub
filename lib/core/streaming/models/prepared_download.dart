import 'package:flutter/foundation.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';

/// The result of preparing a download from a [PlayableSession].
///
/// The Download Engine only understands this object — never provider URLs or
/// provider models.
@immutable
class PreparedDownload {
  final PlayableSession session;
  final bool canDownload;
  final String? suggestedFileName;
  final String? fileExtension;
  final int? expectedSizeBytes;
  final String? reason;

  const PreparedDownload({
    required this.session,
    required this.canDownload,
    this.suggestedFileName,
    this.fileExtension,
    this.expectedSizeBytes,
    this.reason,
  });
}
