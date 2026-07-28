enum MediaSourceType {
  m3u,
  xtream,
  stalker,
  xmltv,
  localPlaylist,
  jellyfin,
  plex,
  emby,
  tvheadend,
  hdHomeRun,
  custom,
  future;

  String get displayName {
    switch (this) {
      case MediaSourceType.m3u:
        return 'M3U';
      case MediaSourceType.xtream:
        return 'Xtream Codes';
      case MediaSourceType.stalker:
        return 'Stalker Portal';
      case MediaSourceType.xmltv:
        return 'XMLTV';
      case MediaSourceType.localPlaylist:
        return 'Local Playlist';
      case MediaSourceType.jellyfin:
        return 'Jellyfin';
      case MediaSourceType.plex:
        return 'Plex';
      case MediaSourceType.emby:
        return 'Emby';
      case MediaSourceType.tvheadend:
        return 'TVHeadend';
      case MediaSourceType.hdHomeRun:
        return 'HDHomeRun';
      case MediaSourceType.custom:
        return 'Custom';
      case MediaSourceType.future:
        return 'Future';
    }
  }

  String get description {
    switch (this) {
      case MediaSourceType.m3u:
        return 'M3U playlist URL or file';
      case MediaSourceType.xtream:
        return 'Xtream Codes API credentials';
      case MediaSourceType.stalker:
        return 'Stalker Portal MAC address';
      case MediaSourceType.xmltv:
        return 'XMLTV electronic program guide';
      case MediaSourceType.localPlaylist:
        return 'Local M3U or XML playlist file';
      case MediaSourceType.jellyfin:
        return 'Jellyfin media server';
      case MediaSourceType.plex:
        return 'Plex media server';
      case MediaSourceType.emby:
        return 'Emby media server';
      case MediaSourceType.tvheadend:
        return 'TVHeadend DVB tuner';
      case MediaSourceType.hdHomeRun:
        return 'HDHomeRun network tuner';
      case MediaSourceType.custom:
        return 'Custom media source';
      case MediaSourceType.future:
        return 'Future source type';
    }
  }
}
