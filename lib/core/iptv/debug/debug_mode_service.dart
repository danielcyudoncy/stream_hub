import 'package:get/get.dart';
import 'package:stream_hub/core/iptv/models/debug_config.dart';
import 'package:stream_hub/core/logging/logging_service.dart';

/// Developer mode service.
///
/// Controls verbose logging, HTTP logging, header logging, session logging,
/// timing instrumentation, and player event logging at runtime. State is
/// exposed reactively so the developer UI can toggle categories live.
class DebugModeService {
  final LoggingService _logger;
  final Rx<DebugConfig> configRx;

  DebugModeService({
    LoggingService? logger,
    DebugConfig initial = DebugConfig.disabled,
  }) : _logger = logger ?? LoggingService(),
       configRx = initial.obs;

  DebugConfig get config => configRx.value;

  bool get isEnabled => config.isEnabled;

  bool isCategoryEnabled(DebugLogCategory category) {
    return config.isCategoryEnabled(category);
  }

  void setConfig(DebugConfig config) {
    configRx.value = config;
    if (config.isEnabled) {
      _logger.info(
        'Developer mode enabled: verbose=${config.verboseLogging} '
        'http=${config.httpLogging} headers=${config.headerLogging} '
        'session=${config.sessionLogging} timing=${config.timingEnabled} '
        'player=${config.playerEventLogging}',
        tag: 'DebugMode',
      );
    }
  }

  /// Toggles a single logging category.
  void toggle(DebugLogCategory category, {bool? value}) {
    final next = value ?? !config.isCategoryEnabled(category);
    final updated = config.copyWith(
      verboseLogging: category == DebugLogCategory.verbose
          ? next
          : config.verboseLogging,
      httpLogging: category == DebugLogCategory.http
          ? next
          : config.httpLogging,
      headerLogging: category == DebugLogCategory.headers
          ? next
          : config.headerLogging,
      sessionLogging: category == DebugLogCategory.session
          ? next
          : config.sessionLogging,
      timingEnabled: category == DebugLogCategory.timing
          ? next
          : config.timingEnabled,
      playerEventLogging: category == DebugLogCategory.playerEvents
          ? next
          : config.playerEventLogging,
    );
    setConfig(updated);
  }

  /// Enables every category at once.
  void enableAll() {
    setConfig(
      const DebugConfig(
        verboseLogging: true,
        httpLogging: true,
        headerLogging: true,
        sessionLogging: true,
        timingEnabled: true,
        playerEventLogging: true,
      ),
    );
  }

  void disableAll() {
    setConfig(DebugConfig.disabled);
  }

  /// Emits a log line only when the given category is enabled.
  void log(
    DebugLogCategory category,
    String message, {
    String? tag,
  }) {
    if (!isCategoryEnabled(category)) return;
    _logger.debug(message, tag: tag ?? 'Debug:$category');
  }

  /// Emits an info line only when the given category is enabled.
  void info(
    DebugLogCategory category,
    String message, {
    String? tag,
  }) {
    if (!isCategoryEnabled(category)) return;
    _logger.info(message, tag: tag ?? 'Debug:$category');
  }
}
