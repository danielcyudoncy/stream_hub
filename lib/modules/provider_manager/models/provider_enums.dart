enum ProviderType {
  m3u,
  xtream,
  stalker,
  xmltv,
  custom;

  String get displayName {
    switch (this) {
      case ProviderType.m3u:
        return 'M3U';
      case ProviderType.xtream:
        return 'Xtream Codes';
      case ProviderType.stalker:
        return 'Stalker Portal';
      case ProviderType.xmltv:
        return 'XMLTV';
      case ProviderType.custom:
        return 'Custom';
    }
  }

  String get description {
    switch (this) {
      case ProviderType.m3u:
        return 'M3U playlist URL or file';
      case ProviderType.xtream:
        return 'Xtream Codes API credentials';
      case ProviderType.stalker:
        return 'Stalker Portal MAC address';
      case ProviderType.xmltv:
        return 'XMLTV electronic program guide';
      case ProviderType.custom:
        return 'Custom provider type';
    }
  }
}

enum ProviderStatus {
  inactive,
  active,
  error,
  syncing;

  String get displayName {
    switch (this) {
      case ProviderStatus.inactive:
        return 'Inactive';
      case ProviderStatus.active:
        return 'Active';
      case ProviderStatus.error:
        return 'Error';
      case ProviderStatus.syncing:
        return 'Syncing';
    }
  }
}

enum ProviderSortField {
  name,
  dateAdded,
  lastUpdated,
  providerType;
}

enum ProviderFilterType {
  all,
  enabled,
  disabled,
  favorites;
}
