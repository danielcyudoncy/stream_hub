class TitleFormatter {
  TitleFormatter._();

  static final RegExp _livePrefixRegex = RegExp(
    r'^(?:(?:[A-Za-z0-9]{2,4}\s*[:|\-]\s*)?(?:\[LIVE\]|\(LIVE\)|LIVE[:|\-\/\.\s]+))\s*',
    caseSensitive: false,
  );

  /// Sanitizes channel titles by stripping redundant "LIVE:", "LIVE |", "[LIVE]" prefixes.
  static String formatChannelTitle(String rawTitle) {
    if (rawTitle.isEmpty) return rawTitle;
    final trimmed = rawTitle.trim();
    final cleaned = trimmed.replaceFirst(_livePrefixRegex, '').trim();
    return cleaned.isNotEmpty ? cleaned : trimmed;
  }
}
