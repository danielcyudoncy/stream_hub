/// Configuration that describes how retries should behave when a stream
/// resolution, validation, or playback attempt fails.
class RetryPolicy {
  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final bool retryOnTimeout;
  final bool retryOnServerError;
  final bool retryOnAuthFailure;
  final Set<int> retryableStatusCodes;

  const RetryPolicy({
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 10),
    this.backoffMultiplier = 2.0,
    this.retryOnTimeout = true,
    this.retryOnServerError = true,
    this.retryOnAuthFailure = false,
    this.retryableStatusCodes = const {408, 429, 500, 502, 503, 504},
  });

  bool get isEnabled => maxRetries > 0;

  /// Computes the delay for the given attempt index (0-based).
  Duration delayForAttempt(int attempt) {
    var delay = baseDelay * pow(backoffMultiplier, attempt);
    if (delay > maxDelay) delay = maxDelay;
    return delay;
  }

  bool shouldRetry({
    required int attempt,
    required int statusCode,
    required bool isTimeout,
    required bool isNetworkError,
    required bool isAuthFailure,
  }) {
    if (attempt >= maxRetries) return false;
    if (isAuthFailure) return retryOnAuthFailure;
    if (isTimeout) return retryOnTimeout;
    if (isNetworkError) return true;
    if (statusCode >= 500 && retryOnServerError) return true;
    return retryableStatusCodes.contains(statusCode);
  }

  RetryPolicy copyWith({
    int? maxRetries,
    Duration? baseDelay,
    Duration? maxDelay,
    double? backoffMultiplier,
    bool? retryOnTimeout,
    bool? retryOnServerError,
    bool? retryOnAuthFailure,
    Set<int>? retryableStatusCodes,
  }) {
    return RetryPolicy(
      maxRetries: maxRetries ?? this.maxRetries,
      baseDelay: baseDelay ?? this.baseDelay,
      maxDelay: maxDelay ?? this.maxDelay,
      backoffMultiplier: backoffMultiplier ?? this.backoffMultiplier,
      retryOnTimeout: retryOnTimeout ?? this.retryOnTimeout,
      retryOnServerError: retryOnServerError ?? this.retryOnServerError,
      retryOnAuthFailure: retryOnAuthFailure ?? this.retryOnAuthFailure,
      retryableStatusCodes: retryableStatusCodes ?? this.retryableStatusCodes,
    );
  }
}

double pow(double base, int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}
