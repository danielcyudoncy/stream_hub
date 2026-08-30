import 'package:stream_hub/data/models/free_tv_channel.dart';

/// Catalog-quality / eligibility layer for Free Live TV.
///
/// The raw IPTV-org catalog is huge and contains many obscure, temporary, test,
/// placeholder, shopping and otherwise low-value channels. This service applies
/// conservative hard exclusions and a lightweight deterministic quality score,
/// then assigns each qualifying channel a [FreeTvQualityTier].
///
/// The score is an internal heuristic for ordering and curation — it is NOT an
/// official popularity or quality metric, and the app never claims it is.
class FreeTvQualityService {
  /// Categories that are broadly useful to general audiences and therefore
  /// score higher in the curated (Recommended) tier.
  static const Set<String> _preferredCategories = {
    'News',
    'Sports',
    'Entertainment',
    'Kids',
    'Documentary',
    'Movies',
    'Music',
    'General',
    'Family',
    'Culture',
    'Lifestyle',
  };

  /// Words that, when they appear as a standalone token in a channel name,
  /// indicate a test / placeholder / demo entry.
  static final RegExp _junkToken =
      RegExp(r'(^|[\s._\-])(test|testing|demo|sample|placeholder|foo|bar)'
          r'([\s._\-]|$)',
          caseSensitive: false);

  /// Quality score thresholds that map to tiers.
  static const int kRecommendedThreshold = 55;
  static const int kGoodThreshold = 35;

  /// Determines whether a channel passes hard eligibility checks.
  ///
  /// This is the "All Valid" gate: NSFW, missing identity/metadata, invalid
  /// streams, and obvious test/placeholder records are removed here.
  bool isEligible(FreeTvChannel channel) {
    if (channel.isNsfw) return false;
    if (channel.id.trim().isEmpty) return false;
    if (channel.name.trim().isEmpty) return false;
    if (channel.streamUrls.isEmpty) return false;
    if (channel.streamUrls.any((u) => !_isValidStreamUrl(u))) return false;
    if (_matchesJunkName(channel.name)) return false;
    return true;
  }

  /// Assigns each eligible channel a tier based on its quality score.
  FreeTvChannel assignTier(FreeTvChannel channel) {
    final qualityValue = score(channel);
    final tier = qualityValue >= kRecommendedThreshold
        ? FreeTvQualityTier.recommended
        : FreeTvQualityTier.valid;
    return channel.copyWith(
      qualityScore: qualityValue,
      qualityTier: tier,
    );
  }

  /// Lightweight quality heuristic (0–100).
  int score(FreeTvChannel channel) {
    var value = 0;

    // Core identity.
    if (channel.id.isNotEmpty) value += 10;
    if (channel.name.isNotEmpty) value += 10;

    // Metadata richness.
    if (channel.logo != null && channel.logo!.trim().isNotEmpty) value += 15;
    if (channel.countryCode.isNotEmpty) value += 8;
    if (channel.region != null && channel.region!.isNotEmpty) value += 3;
    if (channel.languages.isNotEmpty) value += 5;
    if (channel.categories.isNotEmpty) value += 5;

    // Stream robustness (multiple candidates score higher).
    value += channel.streamUrls.length >= 3
        ? 12
        : channel.streamUrls.length == 2
            ? 8
            : 4;

    // Preferred category bonus.
    final hasPreferred = channel.categories.any(
      (c) => _preferredCategories.contains(_normalizeCategory(c)),
    );
    if (hasPreferred) value += 12;

    // Junk/test naming penalty.
    if (_matchesJunkName(channel.name)) value -= 40;

    // Missing meaningful metadata penalty.
    if (channel.countryCode.isEmpty) value -= 8;
    if (channel.logo == null || channel.logo!.trim().isEmpty) value -= 6;

    return value.clamp(0, 100);
  }

  static bool _matchesJunkName(String name) =>
      _junkToken.hasMatch(name.trim());

  static bool _isValidStreamUrl(String url) {
    final trimmed = url.trim();
    if (!trimmed.startsWith(RegExp(r'https?://'))) return false;
    final uri = Uri.tryParse(trimmed);
    return uri != null && uri.host.isNotEmpty;
  }

  static String _normalizeCategory(String category) =>
      category.trim().toLowerCase();
}
