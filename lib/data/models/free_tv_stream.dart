/// Represents an individual stream candidate for a Free Live TV channel.
///
/// A single channel can have multiple stream sources with varying resolutions,
/// bitrates, and health metrics.
class FreeTvStream {
  final String url;
  final String? quality;
  final String? label;
  final bool isOnline;
  final double? healthScore;
  final int? bitrate;
  final int? height;
  final String? referrer;
  final String? userAgent;

  const FreeTvStream({
    required this.url,
    this.quality,
    this.label,
    this.isOnline = true,
    this.healthScore,
    this.bitrate,
    this.height,
    this.referrer,
    this.userAgent,
  });

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      if (quality != null) 'quality': quality,
      if (label != null) 'label': label,
      'is_online': isOnline,
      if (healthScore != null) 'health_score': healthScore,
      if (bitrate != null) 'bitrate': bitrate,
      if (height != null) 'height': height,
      if (referrer != null) 'referrer': referrer,
      if (userAgent != null) 'user_agent': userAgent,
    };
  }

  factory FreeTvStream.fromJson(Map<String, dynamic> json) {
    final rawHealth = json['health_score'];
    final double? healthScore = rawHealth is num ? rawHealth.toDouble() : null;
    return FreeTvStream(
      url: (json['url'] ?? '').toString(),
      quality: json['quality']?.toString(),
      label: json['label']?.toString(),
      isOnline: json['is_online'] != false,
      healthScore: healthScore,
      bitrate: (json['bitrate'] is num) ? (json['bitrate'] as num).toInt() : null,
      height: (json['height'] is num) ? (json['height'] as num).toInt() : null,
      referrer: json['referrer']?.toString(),
      userAgent: json['user_agent']?.toString(),
    );
  }

  FreeTvStream copyWith({
    String? url,
    String? quality,
    String? label,
    bool? isOnline,
    double? healthScore,
    int? bitrate,
    int? height,
    String? referrer,
    String? userAgent,
  }) {
    return FreeTvStream(
      url: url ?? this.url,
      quality: quality ?? this.quality,
      label: label ?? this.label,
      isOnline: isOnline ?? this.isOnline,
      healthScore: healthScore ?? this.healthScore,
      bitrate: bitrate ?? this.bitrate,
      height: height ?? this.height,
      referrer: referrer ?? this.referrer,
      userAgent: userAgent ?? this.userAgent,
    );
  }
}
