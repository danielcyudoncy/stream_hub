import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/models/m3u_models.dart';
import 'package:stream_hub/data/sources/free_tv_regions.dart';

/// Normalizes parsed IPTV-org M3U records into [FreeTvChannel] records.
///
/// IPTV-org playlists encode stable channel identity and country inside the
/// `tvg-id` attribute in the form `<channel>.<country>@<SD|HD>`, with multiple
/// resolution variants of the same channel appearing as separate entries. This
/// normalizer extracts that identity, strips resolution/geoblock markers from
/// the display name, and splits multi-value `group-title` attributes into a
/// category list.
class FreeTvM3uNormalizer {
  /// Regex for IPTV-org `tvg-id` identity: `<channel>.<cc>@<SD|HD>`.
  static final RegExp _tvgIdPattern =
      RegExp(r'^(.+)\.([a-zA-Z]{2})@(SD|HD|FHD|UHD)$');

  /// Strips trailing resolution / segment markers from EXTINF display names,
  /// e.g. `BBC News (1080p)`, `Channel [Geo-blocked]`, `Foo [Not 24/7]`, `Foo HD`.
  static final RegExp _displayNameSuffix = RegExp(
    r'\s*(?:\(\d{3,4}p\)|\[[^\]]*\]|\bHD\b|\bSD\b|\bFHD\b|\bUHD\b)\s*$',
  );

  /// Splits the IPTV-org multi-value `group-title` (e.g. `News;Public`).
  static List<String> _splitGroup(String? group) {
    if (group == null || group.trim().isEmpty) return const [];
    return group
        .split(RegExp(r'[;,]'))
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .toList();
  }

  /// Derives a stable channel ID and optional country code from a `tvg-id`.
  static ({String id, String? countryCode}) _parseTvgId(String? tvgId) {
    final raw = (tvgId ?? '').trim();
    if (raw.isEmpty) return (id: '', countryCode: null);
    final match = _tvgIdPattern.firstMatch(raw);
    if (match != null) {
      return (id: match.group(1)!.trim(), countryCode: match.group(2)!);
    }
    final atIndex = raw.indexOf('@');
    final withoutQuality = atIndex >= 0 ? raw.substring(0, atIndex).trim() : raw;
    return (id: withoutQuality, countryCode: null);
  }

  /// Builds a normalized [FreeTvChannel] from a single parsed M3U entry.
  ///
  /// [sourceCountryCode] overrides/extracts the country when the record itself
  /// does not carry one (e.g. records inside a country-specific playlist).
  /// [sourceCategory] is appended when the source is a category playlist.
  FreeTvChannel? toChannel(
    M3UChannel m3u, {
    String? sourceCountryCode,
    String? sourceCategory,
  }) {
    final title = m3u.title.trim();
    final streamUrl = (m3u.streamUrl ?? '').trim();

    if (title.isEmpty || streamUrl.isEmpty) return null;
    if (!streamUrl.startsWith(RegExp(r'https?://'))) return null;

    final parsed = _parseTvgId(m3u.tvgId);
    var id = parsed.id;
    var countryCode = parsed.countryCode ??
        sourceCountryCode ??
        (m3u.country != null && m3u.country!.trim().length <= 3
            ? m3u.country!.trim()
            : null);

    // When we cannot derive a stable ID, fall back to host + title slug so the
    // record is still browsable and dedupeable.
    if (id.isEmpty) {
      id = _fallbackId(title, streamUrl);
    }

    final cleanName = _cleanDisplayName(
      m3u.tvgName != null && m3u.tvgName!.trim().isNotEmpty
          ? m3u.tvgName!
          : title,
    ).trim();

    var categories = _splitGroup(m3u.group);
    if (sourceCategory != null &&
        sourceCategory.isNotEmpty &&
        !categories.contains(sourceCategory)) {
      categories = [...categories, sourceCategory];
    }

    final countryName =
        countryCode != null && countryCode.isNotEmpty
            ? (FreeTvRegions.countryNameForCode(countryCode) ??
                  countryCode)
            : (m3u.country != null && m3u.country!.trim().length > 3
                  ? m3u.country!.trim()
                  : 'Unknown');

    return FreeTvChannel(
      id: id,
      name: cleanName.isNotEmpty ? cleanName : title,
      country: countryCode != null && countryCode.isNotEmpty
          ? countryName
          : 'Unknown',
      countryCode: countryCode ?? '',
      region: FreeTvRegions.regionForCountryCode(countryCode ?? ''),
      languages: _splitGroup(
        m3u.language != null && m3u.language!.trim().isNotEmpty
            ? m3u.language
            : null,
      ),
      categories: categories.toSet().toList(),
      logo: _validHttpUrl(m3u.logo),
      streamUrls: [streamUrl],
      isNsfw: false,
    );
  }

  static String _fallbackId(String title, String streamUrl) {
    String slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) slug = 'channel';
    final host = Uri.tryParse(streamUrl)?.host ?? 'unknown';
    return '$host-$slug';
  }

  static String _cleanDisplayName(String name) {
    var result = name.replaceAll(_displayNameSuffix, '').trim();
    // Some playlists append a bare country/quality " HD "/" SD " in parens-free
    // form; collapse repeated whitespace.
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    return result;
  }

  static String? _validHttpUrl(String? url) {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.startsWith(RegExp(r'https?://'))) return trimmed;
    return null;
  }
}
