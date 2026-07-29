enum MetadataSourceType {
  xmltv,
  tmdb,
  tvmaze,
  imdb,
  trakt,
  fanart,
  provider,
  local,
  custom;

  String get displayName {
    switch (this) {
      case MetadataSourceType.xmltv:
        return 'XMLTV';
      case MetadataSourceType.tmdb:
        return 'TMDB';
      case MetadataSourceType.tvmaze:
        return 'TVMaze';
      case MetadataSourceType.imdb:
        return 'IMDb';
      case MetadataSourceType.trakt:
        return 'Trakt';
      case MetadataSourceType.fanart:
        return 'Fanart.tv';
      case MetadataSourceType.provider:
        return 'Provider Native';
      case MetadataSourceType.local:
        return 'Local';
      case MetadataSourceType.custom:
        return 'Custom';
    }
  }
}