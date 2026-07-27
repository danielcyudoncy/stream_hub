enum AppEnvironment {
  development,
  staging,
  production,
}

class EnvironmentConfig {
  final AppEnvironment environment;
  final String apiBaseUrl;
  final bool enableCrashlytics;
  final bool enableAnalytics;

  const EnvironmentConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.enableCrashlytics,
    required this.enableAnalytics,
  });

  factory EnvironmentConfig.development() {
    return const EnvironmentConfig(
      environment: AppEnvironment.development,
      apiBaseUrl: 'https://dev.api.streamhubpro.com',
      enableCrashlytics: false,
      enableAnalytics: false,
    );
  }

  factory EnvironmentConfig.staging() {
    return const EnvironmentConfig(
      environment: AppEnvironment.staging,
      apiBaseUrl: 'https://staging.api.streamhubpro.com',
      enableCrashlytics: true,
      enableAnalytics: true,
    );
  }

  factory EnvironmentConfig.production() {
    return const EnvironmentConfig(
      environment: AppEnvironment.production,
      apiBaseUrl: 'https://api.streamhubpro.com',
      enableCrashlytics: true,
      enableAnalytics: true,
    );
  }
}
