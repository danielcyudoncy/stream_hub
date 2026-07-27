import 'environment.dart';

class AppConfig {
  static AppConfig? _instance;

  final EnvironmentConfig environmentConfig;
  final String appName;
  final String appVersion;
  final String buildNumber;

  AppConfig._({
    required this.environmentConfig,
    required this.appName,
    required this.appVersion,
    required this.buildNumber,
  });

  static void initialize({
    required EnvironmentConfig environmentConfig,
    required String appName,
    required String appVersion,
    required String buildNumber,
  }) {
    _instance = AppConfig._(
      environmentConfig: environmentConfig,
      appName: appName,
      appVersion: appVersion,
      buildNumber: buildNumber,
    );
  }

  static AppConfig get instance {
    if (_instance == null) {
      throw StateError('AppConfig must be initialized first.');
    }
    return _instance!;
  }

  bool get isDevelopment => environmentConfig.environment == AppEnvironment.development;
  bool get isStaging => environmentConfig.environment == AppEnvironment.staging;
  bool get isProduction => environmentConfig.environment == AppEnvironment.production;
}
