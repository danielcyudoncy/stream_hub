/// Account metadata reported by a provider's backend (e.g. an Xtream panel's
/// `user_info`): subscription creation and expiry dates, plan status, trial
/// flag, and concurrent connection limit.
class AccountMetadata {
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final String? status;
  final String? message;
  final bool? isTrial;
  final int? maxConnections;

  const AccountMetadata({
    this.createdAt,
    this.expiresAt,
    this.status,
    this.message,
    this.isTrial,
    this.maxConnections,
  });

  /// Parses a panel `user_info` map. `created_at` and `exp_date` are Unix
  /// epoch seconds; an `exp_date` of `0` (or missing) means the subscription
  /// never expires, so [expiresAt] stays `null`.
  factory AccountMetadata.fromUserInfo(Map<dynamic, dynamic> userInfo) {
    return AccountMetadata(
      createdAt: _parseEpoch(userInfo['created_at']),
      expiresAt: _parseEpoch(userInfo['exp_date']),
      status: userInfo['status']?.toString(),
      message: userInfo['message']?.toString(),
      isTrial: _parseBool(userInfo['is_trial']),
      maxConnections: _parseInt(userInfo['max_connections']),
    );
  }

  static DateTime? _parseEpoch(dynamic raw) {
    final value = _parseInt(raw);
    if (value == null || value <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }

  static int? _parseInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is String && raw.isNotEmpty) return int.tryParse(raw);
    return null;
  }

  static bool? _parseBool(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is int) return raw == 1;
    if (raw is String) {
      return raw == '1' || raw.toLowerCase() == 'true';
    }
    return null;
  }
}
