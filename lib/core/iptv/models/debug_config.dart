import 'package:flutter/foundation.dart';

/// Developer-mode logging categories.
enum DebugLogCategory {
  verbose,
  http,
  headers,
  session,
  timing,
  playerEvents;

  String get displayName {
    switch (this) {
      case DebugLogCategory.verbose:
        return 'Verbose';
      case DebugLogCategory.http:
        return 'HTTP';
      case DebugLogCategory.headers:
        return 'Headers';
      case DebugLogCategory.session:
        return 'Session';
      case DebugLogCategory.timing:
        return 'Timing';
      case DebugLogCategory.playerEvents:
        return 'Player Events';
    }
  }
}

/// Configuration for developer mode.
///
/// Controls verbose logging, HTTP logging, header logging, session logging,
/// timing instrumentation, and player event logging. Defaults to disabled so
/// production builds remain quiet.
@immutable
class DebugConfig {
  final bool verboseLogging;
  final bool httpLogging;
  final bool headerLogging;
  final bool sessionLogging;
  final bool timingEnabled;
  final bool playerEventLogging;
  final bool redactSensitiveData;

  const DebugConfig({
    this.verboseLogging = false,
    this.httpLogging = false,
    this.headerLogging = false,
    this.sessionLogging = false,
    this.timingEnabled = false,
    this.playerEventLogging = false,
    this.redactSensitiveData = true,
  });

  static const DebugConfig disabled = DebugConfig();

  bool get isEnabled =>
      verboseLogging ||
      httpLogging ||
      headerLogging ||
      sessionLogging ||
      timingEnabled ||
      playerEventLogging;

  bool isCategoryEnabled(DebugLogCategory category) {
    switch (category) {
      case DebugLogCategory.verbose:
        return verboseLogging;
      case DebugLogCategory.http:
        return httpLogging;
      case DebugLogCategory.headers:
        return headerLogging;
      case DebugLogCategory.session:
        return sessionLogging;
      case DebugLogCategory.timing:
        return timingEnabled;
      case DebugLogCategory.playerEvents:
        return playerEventLogging;
    }
  }

  DebugConfig copyWith({
    bool? verboseLogging,
    bool? httpLogging,
    bool? headerLogging,
    bool? sessionLogging,
    bool? timingEnabled,
    bool? playerEventLogging,
    bool? redactSensitiveData,
  }) {
    return DebugConfig(
      verboseLogging: verboseLogging ?? this.verboseLogging,
      httpLogging: httpLogging ?? this.httpLogging,
      headerLogging: headerLogging ?? this.headerLogging,
      sessionLogging: sessionLogging ?? this.sessionLogging,
      timingEnabled: timingEnabled ?? this.timingEnabled,
      playerEventLogging: playerEventLogging ?? this.playerEventLogging,
      redactSensitiveData: redactSensitiveData ?? this.redactSensitiveData,
    );
  }
}
