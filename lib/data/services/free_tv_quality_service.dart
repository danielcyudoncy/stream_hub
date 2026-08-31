import 'package:stream_hub/data/models/free_tv_channel.dart';

/// Catalog-quality / eligibility layer for Free Live TV.
///
/// Filters out NSFW, temporary, test, placeholder, malformed, or dead-stream records,
/// and applies a deterministic quality heuristic (0–100) to assign each qualifying
/// channel to a [FreeTvQualityTier] (Recommended vs Valid).
class FreeTvQualityService {
  /// Categories that are broadly useful to general audiences and therefore
  /// score higher in the curated (Recommended) tier.
  static const Set<String> _preferredCategories = {
    'news',
    'sports',
    'entertainment',
    'kids',
    'documentary',
    'movies',
    'music',
    'general',
    'family',
    'culture',
    'lifestyle',
    'series',
    'education',
    'animation',
  };

  /// Standalone tokens that indicate a test / placeholder / demo entry.
  static final RegExp _junkToken = RegExp(
    r'(^|[\s._\-])(test|testing|demo|sample|placeholder|temp|foo|bar)([\s._\-]|$)',
    caseSensitive: false,
  );

  /// Quality score thresholds that map to tiers.
  static const int kRecommendedThreshold = 55;
  static const int kGoodThreshold = 35;

  /// Whether to filter out non-English channels.
  final bool englishOnly;

  const FreeTvQualityService({this.englishOnly = true});

  /// Determines whether a channel passes hard eligibility checks.
  ///
  /// This is the "All Valid" gate: NSFW, missing identity/metadata, invalid
  /// streams, non-English (when [englishOnly] is true), and obvious test/placeholder
  /// records are removed here.
  bool isEligible(FreeTvChannel channel) {
    if (channel.isNsfw) return false;
    if (channel.id.trim().isEmpty) return false;
    if (channel.name.trim().isEmpty) return false;
    if (!channel.hasStream) return false;

    // Verify all stream URLs
    final urls = channel.streamUrls.isNotEmpty
        ? channel.streamUrls
        : channel.streams.map((s) => s.url).toList();
    if (urls.isEmpty) return false;
    if (urls.any((u) => !_isValidStreamUrl(u))) return false;

    if (_matchesJunkName(channel.name)) return false;

    // Enforce English-only channels if configured
    if (englishOnly) {
      final hasEnglish = channel.languages.any((l) {
        final lower = l.trim().toLowerCase();
        return lower == 'english' || lower == 'eng' || lower == 'en';
      });
      if (!hasEnglish) return false;
    }

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

    // 1. Core identity (+20)
    if (channel.id.isNotEmpty) value += 10;
    if (channel.name.isNotEmpty) value += 10;

    // 2. Metadata richness (+35)
    if (channel.logo != null && channel.logo!.trim().isNotEmpty) value += 15;
    if (channel.countryCode.isNotEmpty) value += 8;
    if (channel.region != null && channel.region!.isNotEmpty) value += 4;
    if (channel.languages.isNotEmpty) value += 4;
    if (channel.categories.isNotEmpty) value += 4;

    // 3. Stream robustness & upstream health (+25)
    final onlineCount = channel.streams.where((s) => s.isOnline).length;
    if (onlineCount > 0 || channel.isWorking == true) {
      value += 15;
    }
    if (channel.streams.length >= 3 || channel.streamUrls.length >= 3) {
      value += 10;
    } else if (channel.streams.length == 2 || channel.streamUrls.length == 2) {
      value += 6;
    } else {
      value += 2;
    }

    // 4. Preferred category bonus (+12)
    final hasPreferred = channel.categories.any(
      (c) => _preferredCategories.contains(_normalizeCategory(c)),
    );
    if (hasPreferred) value += 12;

    // 5. HD / Best quality bonus (+8)
    final hasHd = channel.streams.any((s) {
      final q = s.quality?.toLowerCase() ?? '';
      return q.contains('1080') || q.contains('720') || (s.height != null && s.height! >= 720);
    });
    if (hasHd) value += 8;

    // 6. Junk/test naming penalty (-40)
    if (_matchesJunkName(channel.name)) value -= 40;

    // 7. Missing critical metadata penalties
    if (channel.countryCode.isEmpty) value -= 8;
    if (channel.logo == null || channel.logo!.trim().isEmpty) value -= 10;

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
