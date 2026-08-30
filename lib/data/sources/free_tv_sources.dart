/// Centralized configuration of the public IPTV-org free live TV playlist
/// sources used to build the provider-free catalog.
///
/// Keeping every URL here (instead of scattering it across services/widgets)
/// makes future source additions and removals a one-file change.
library;

/// Characterizes the kind of a Free TV source group so the UI can present it
/// consistently (Country vs Region vs Category vs Global).
enum FreeTvSourceKind {
  global,
  country,
  region,
  category,
}

/// A single IPTV-org playlist source.
class FreeTvSource {
  final String id;
  final String name;
  final String url;
  final FreeTvSourceKind kind;
  final String? countryCode;
  final String? regionCode;
  final String? categoryName;

  const FreeTvSource({
    required this.id,
    required this.name,
    required this.url,
    required this.kind,
    this.countryCode,
    this.regionCode,
    this.categoryName,
  });
}

/// All known public IPTV-org playlists used by the Free TV catalog.
abstract final class FreeTvSources {
  static const String _base = 'https://iptv-org.github.io/iptv';

  /// Broadest source. Every channel passes through the quality/eligibility
  /// layer; it is never shown wholesale.
  static const FreeTvSource global = FreeTvSource(
    id: 'global',
    name: 'All Channels',
    url: '$_base/index.m3u',
    kind: FreeTvSourceKind.global,
  );

  // --- Country sources ---

  static const FreeTvSource nigeria = FreeTvSource(
    id: 'nigeria',
    name: 'Nigeria',
    url: '$_base/countries/ng.m3u',
    kind: FreeTvSourceKind.country,
    countryCode: 'NG',
  );

  static const FreeTvSource southAfrica = FreeTvSource(
    id: 'south_africa',
    name: 'South Africa',
    url: '$_base/countries/za.m3u',
    kind: FreeTvSourceKind.country,
    countryCode: 'ZA',
  );

  static const FreeTvSource unitedKingdom = FreeTvSource(
    id: 'united_kingdom',
    name: 'United Kingdom',
    url: '$_base/countries/uk.m3u',
    kind: FreeTvSourceKind.country,
    countryCode: 'UK',
  );

  static const FreeTvSource unitedStates = FreeTvSource(
    id: 'united_states',
    name: 'United States',
    url: '$_base/countries/us.m3u',
    kind: FreeTvSourceKind.country,
    countryCode: 'US',
  );

  static const FreeTvSource france = FreeTvSource(
    id: 'france',
    name: 'France',
    url: '$_base/countries/fr.m3u',
    kind: FreeTvSourceKind.country,
    countryCode: 'FR',
  );

  static const FreeTvSource germany = FreeTvSource(
    id: 'germany',
    name: 'Germany',
    url: '$_base/countries/de.m3u',
    kind: FreeTvSourceKind.country,
    countryCode: 'DE',
  );

  // --- Region sources ---

  static const FreeTvSource africa = FreeTvSource(
    id: 'africa',
    name: 'Africa',
    url: '$_base/regions/afr.m3u',
    kind: FreeTvSourceKind.region,
    regionCode: 'AF',
  );

  static const FreeTvSource americas = FreeTvSource(
    id: 'americas',
    name: 'Americas',
    url: '$_base/regions/amer.m3u',
    kind: FreeTvSourceKind.region,
    regionCode: 'AMER',
  );

  static const FreeTvSource asia = FreeTvSource(
    id: 'asia',
    name: 'Asia',
    url: '$_base/regions/asia.m3u',
    kind: FreeTvSourceKind.region,
    regionCode: 'ASIA',
  );

  // --- Category sources ---

  static const FreeTvSource news = FreeTvSource(
    id: 'news',
    name: 'News',
    url: '$_base/categories/news.m3u',
    kind: FreeTvSourceKind.category,
    categoryName: 'News',
  );

  static const FreeTvSource sports = FreeTvSource(
    id: 'sports',
    name: 'Sports',
    url: '$_base/categories/sports.m3u',
    kind: FreeTvSourceKind.category,
    categoryName: 'Sports',
  );

  static const FreeTvSource entertainment = FreeTvSource(
    id: 'entertainment',
    name: 'Entertainment',
    url: '$_base/categories/entertainment.m3u',
    kind: FreeTvSourceKind.category,
    categoryName: 'Entertainment',
  );

  static const FreeTvSource kids = FreeTvSource(
    id: 'kids',
    name: 'Kids',
    url: '$_base/categories/kids.m3u',
    kind: FreeTvSourceKind.category,
    categoryName: 'Kids',
  );

  static const FreeTvSource documentary = FreeTvSource(
    id: 'documentary',
    name: 'Documentary',
    url: '$_base/categories/documentary.m3u',
    kind: FreeTvSourceKind.category,
    categoryName: 'Documentary',
  );

  /// Every source used to build the unified catalog.
  static const List<FreeTvSource> all = [
    global,
    nigeria,
    southAfrica,
    unitedKingdom,
    unitedStates,
    france,
    germany,
    africa,
    americas,
    asia,
    news,
    sports,
    entertainment,
    kids,
    documentary,
  ];

  /// Country sources surfaced as dedicated country sections in the UI.
  static const List<FreeTvSource> countries = [
    nigeria,
    southAfrica,
    unitedKingdom,
    unitedStates,
    france,
    germany,
  ];

  /// Region sources surfaced as dedicated region sections in the UI.
  static const List<FreeTvSource> regions = [africa, americas, asia];

  /// Category sources surfaced as dedicated category sections in the UI.
  static const List<FreeTvSource> categories = [
    news,
    sports,
    entertainment,
    kids,
    documentary,
  ];
}
