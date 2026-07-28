import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/media_source.dart';
import 'package:stream_hub/data/providers/stubs/custom_source.dart';
import 'package:stream_hub/data/providers/stubs/emby_source.dart';
import 'package:stream_hub/data/providers/stubs/future_source.dart';
import 'package:stream_hub/data/providers/stubs/hd_home_run_source.dart';
import 'package:stream_hub/data/providers/stubs/jellyfin_source.dart';
import 'package:stream_hub/data/providers/stubs/local_playlist_source.dart';
import 'package:stream_hub/data/providers/stubs/m3u_source.dart';
import 'package:stream_hub/data/providers/stubs/plex_source.dart';
import 'package:stream_hub/data/providers/stubs/stalker_source.dart';
import 'package:stream_hub/data/providers/stubs/tvheadend_source.dart';
import 'package:stream_hub/data/providers/stubs/xmltv_source.dart';
import 'package:stream_hub/data/providers/stubs/xtream_source.dart';

abstract class MediaSourceFactory {
  MediaSource create(String id, MediaSourceType type, Map<String, dynamic> config);
}

class DefaultMediaSourceFactory implements MediaSourceFactory {
  @override
  MediaSource create(String id, MediaSourceType type, Map<String, dynamic> config) {
    switch (type) {
      case MediaSourceType.m3u:
        return M3USource(id: id, config: config);
      case MediaSourceType.xtream:
        return XtreamSource(id: id, config: config);
      case MediaSourceType.stalker:
        return StalkerSource(id: id, config: config);
      case MediaSourceType.xmltv:
        return XMLTVSource(id: id, config: config);
      case MediaSourceType.localPlaylist:
        return LocalPlaylistSource(id: id, config: config);
      case MediaSourceType.jellyfin:
        return JellyfinSource(id: id, config: config);
      case MediaSourceType.plex:
        return PlexSource(id: id, config: config);
      case MediaSourceType.emby:
        return EmbySource(id: id, config: config);
      case MediaSourceType.tvheadend:
        return TVHeadendSource(id: id, config: config);
      case MediaSourceType.hdHomeRun:
        return HDHomeRunSource(id: id, config: config);
      case MediaSourceType.custom:
        return CustomSource(id: id, config: config);
      case MediaSourceType.future:
        return FutureSource(id: id, config: config);
    }
  }
}
