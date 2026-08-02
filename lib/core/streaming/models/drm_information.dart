import 'package:flutter/foundation.dart';

/// Digital rights management information attached to a [PlayableSession].
@immutable
class DrmInformation {
  final String? scheme;
  final String? licenseUrl;
  final Map<String, String>? licenseHeaders;
  final String? token;
  final Map<String, dynamic>? extra;

  const DrmInformation({
    this.scheme,
    this.licenseUrl,
    this.licenseHeaders,
    this.token,
    this.extra,
  });

  bool get isDrmProtected => scheme != null && licenseUrl != null;

  Map<String, dynamic> toMap() {
    return {
      if (scheme != null) 'scheme': scheme,
      if (licenseUrl != null) 'licenseUrl': licenseUrl,
      if (licenseHeaders != null) 'licenseHeaders': licenseHeaders,
      if (token != null) 'token': token,
      if (extra != null) 'extra': extra,
    };
  }

  DrmInformation copyWith({
    String? scheme,
    String? licenseUrl,
    Map<String, String>? licenseHeaders,
    String? token,
    Map<String, dynamic>? extra,
  }) {
    return DrmInformation(
      scheme: scheme ?? this.scheme,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      licenseHeaders: licenseHeaders ?? this.licenseHeaders,
      token: token ?? this.token,
      extra: extra ?? this.extra,
    );
  }
}
