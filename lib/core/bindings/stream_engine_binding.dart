import 'dart:async';
import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/auth/authentication_engine.dart';
import 'package:stream_hub/core/streaming/auth/providers/bearer_token_authentication_provider.dart';
import 'package:stream_hub/core/streaming/auth/providers/m3u_authentication_provider.dart';
import 'package:stream_hub/core/streaming/auth/providers/stalker_authentication_provider.dart';
import 'package:stream_hub/core/streaming/auth/providers/xtream_authentication_provider.dart';
import 'package:stream_hub/core/streaming/background/stream_task_manager.dart';
import 'package:stream_hub/core/streaming/cache/session_cache.dart';
import 'package:stream_hub/core/streaming/cache/stream_cache.dart';
import 'package:stream_hub/core/streaming/controllers/authentication_controller.dart';
import 'package:stream_hub/core/streaming/controllers/playback_session_controller.dart';
import 'package:stream_hub/core/streaming/controllers/session_controller.dart';
import 'package:stream_hub/core/streaming/controllers/stream_health_controller.dart';
import 'package:stream_hub/core/streaming/download/download_preparation_service.dart';
import 'package:stream_hub/core/streaming/events/stream_event_bus.dart';
import 'package:stream_hub/core/streaming/failover/failover_manager.dart';
import 'package:stream_hub/core/streaming/factory/playable_session_factory.dart';
import 'package:stream_hub/core/streaming/health/stream_health_monitor.dart';
import 'package:stream_hub/core/streaming/models/stream_probe.dart';
import 'package:stream_hub/core/streaming/network/cookie_manager.dart';
import 'package:stream_hub/core/streaming/network/dart_http_probe.dart';
import 'package:stream_hub/core/streaming/network/header_engine.dart';
import 'package:stream_hub/core/streaming/network/url_normalizer.dart';
import 'package:stream_hub/core/streaming/repositories/authentication_repository.dart';
import 'package:stream_hub/core/streaming/repositories/stream_cache_repository.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/core/streaming/resolver/composite_stream_resolver.dart';
import 'package:stream_hub/core/streaming/resolver/default_stream_resolver.dart';
import 'package:stream_hub/core/streaming/resolver/stalker_stream_resolver.dart';
import 'package:stream_hub/core/streaming/resolver/stream_resolver.dart';
import 'package:stream_hub/core/streaming/resolver/xtream_stream_resolver.dart';
import 'package:stream_hub/core/streaming/security/data_encryption.dart';
import 'package:stream_hub/core/streaming/series/xtream_series_info_service.dart';
import 'package:stream_hub/core/streaming/vod/xtream_vod_info_service.dart';
import 'package:stream_hub/core/streaming/session/factories/bearer_server_provider_session_factory.dart';
import 'package:stream_hub/core/streaming/session/factories/m3u_provider_session_factory.dart';
import 'package:stream_hub/core/streaming/session/factories/stalker_provider_session_factory.dart';
import 'package:stream_hub/core/streaming/session/factories/xtream_provider_session_factory.dart';
import 'package:stream_hub/core/streaming/session/provider_session_factory_registry.dart';
import 'package:stream_hub/core/streaming/session/session_manager.dart';
import 'package:stream_hub/core/streaming/stream_engine.dart';
import 'package:stream_hub/core/streaming/validation/stream_validator.dart';
import 'package:stream_hub/data/repositories/authentication_repository_impl.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/data/repositories/stream_cache_repository_impl.dart';
import 'package:stream_hub/data/repositories/stream_repository_impl.dart';
import 'package:stream_hub/data/services/provider_session_local_service.dart';

/// Wires the Stream Engine dependency graph using GetX.
class StreamEngineBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<StreamEventBus>(StreamEventBus(), permanent: true);
    Get.put<UrlNormalizer>(UrlNormalizer(), permanent: true);
    Get.put<HeaderEngine>(HeaderEngine(), permanent: true);
    Get.put<CookieManager>(CookieManager(), permanent: true);
    Get.put<HttpProbe>(const DartHttpProbe(), permanent: true);
    Get.put<StreamCache>(StreamCache(), permanent: true);

    final localService = ProviderSessionLocalService(
      logger: Get.find<LoggingService>(),
    );
    Get.put<ProviderSessionLocalService>(localService, permanent: true);
    unawaited(localService.init());

    Get.put<SessionCache>(
      SessionCache(
        Get.find<ProviderSessionLocalService>(),
        encryption: Get.isRegistered<DataEncryption>()
            ? Get.find<DataEncryption>()
            : LocalDataObfuscator.fromSeed(
                DateTime.now().millisecondsSinceEpoch),
      ),
      permanent: true,
    );

    final authEngine = AuthenticationEngine(eventBus: Get.find<StreamEventBus>());
    authEngine.registerProvider(M3UAuthenticationProvider());
    authEngine.registerProvider(XtreamAuthenticationProvider());
    authEngine.registerProvider(StalkerAuthenticationProvider());
    authEngine.registerProvider(
      const BearerTokenAuthenticationProvider(MediaSourceType.plex),
    );
    authEngine.registerProvider(
      const BearerTokenAuthenticationProvider(MediaSourceType.jellyfin),
    );
    authEngine.registerProvider(
      const BearerTokenAuthenticationProvider(MediaSourceType.emby),
    );
    Get.put<AuthenticationEngine>(authEngine, permanent: true);

    final registry = ProviderSessionFactoryRegistry();
    registry.register(M3UProviderSessionFactory());
    registry.register(const BearerServerProviderSessionFactory(
      MediaSourceType.plex,
    ));
    registry.register(const BearerServerProviderSessionFactory(
      MediaSourceType.jellyfin,
    ));
    registry.register(const BearerServerProviderSessionFactory(
      MediaSourceType.emby,
    ));
    registry.register(XtreamProviderSessionFactory());
    registry.register(StalkerProviderSessionFactory());
    Get.put<ProviderSessionFactoryRegistry>(registry, permanent: true);

    final sessionManager = SessionManager(
      sessionCache: Get.find<SessionCache>(),
      authenticationEngine: authEngine,
      cookieManager: Get.find<CookieManager>(),
      registry: registry,
      eventBus: Get.find<StreamEventBus>(),
      logger: Get.find<LoggingService>(),
    );
    Get.put<SessionManager>(sessionManager, permanent: true);

    Get.put<XtreamSeriesInfoService>(
      XtreamSeriesInfoService(logger: Get.find<LoggingService>()),
      permanent: true,
    );

    Get.put<XtreamVodInfoService>(
      XtreamVodInfoService(logger: Get.find<LoggingService>()),
      permanent: true,
    );

    Get.put<StreamResolver>(
      CompositeStreamResolver(
        fallback: DefaultStreamResolver(
          normalizer: Get.find<UrlNormalizer>(),
          probe: Get.find<HttpProbe>(),
        ),
        resolvers: {
          MediaSourceType.stalker: StalkerStreamResolver(
            normalizer: Get.find<UrlNormalizer>(),
            logger: Get.find<LoggingService>(),
          ),
          MediaSourceType.xtream: XtreamStreamResolver(
            normalizer: Get.find<UrlNormalizer>(),
            logger: Get.find<LoggingService>(),
            seriesInfoService: Get.find<XtreamSeriesInfoService>(),
          ),
        },
      ),
      permanent: true,
    );
    Get.put<StreamValidator>(
      StreamValidator(
        probe: Get.find<HttpProbe>(),
      ),
      permanent: true,
    );
    Get.put<StreamHealthMonitor>(
      StreamHealthMonitor(eventBus: Get.find<StreamEventBus>()),
      permanent: true,
    );
    Get.put<PlayableSessionFactory>(
      PlayableSessionFactory(),
      permanent: true,
    );
    Get.put<FailoverManager>(FailoverManager(), permanent: true);
    Get.put<DownloadPreparationService>(
      DownloadPreparationService(
        cookieManager: Get.find<CookieManager>(),
        headerEngine: Get.find<HeaderEngine>(),
      ),
      permanent: true,
    );

    final streamEngine = StreamEngine(
      sessionManager: sessionManager,
      resolver: Get.find<StreamResolver>(),
      authenticationEngine: authEngine,
      headerEngine: Get.find<HeaderEngine>(),
      cookieManager: Get.find<CookieManager>(),
      urlNormalizer: Get.find<UrlNormalizer>(),
      streamValidator: Get.find<StreamValidator>(),
      healthMonitor: Get.find<StreamHealthMonitor>(),
      streamCache: Get.find<StreamCache>(),
      playableSessionFactory: Get.find<PlayableSessionFactory>(),
      downloadPreparationService: Get.find<DownloadPreparationService>(),
      failoverManager: Get.find<FailoverManager>(),
      eventBus: Get.find<StreamEventBus>(),
      logger: Get.find<LoggingService>(),
      taskManager: StreamTaskManager(
        sessionCache: Get.find<SessionCache>(),
        cookieManager: Get.find<CookieManager>(),
        streamCache: Get.find<StreamCache>(),
        authenticationEngine: authEngine,
        logger: Get.find<LoggingService>(),
      ),
      providerConfigProvider: (providerId) async {
        final repo = Get.isRegistered<ProviderRepository>()
            ? Get.find<ProviderRepository>()
            : null;
        final provider = await repo?.getProviderById(providerId);
        if (provider == null) return null;
        return {
          'providerId': provider.id,
          'serverUrl': provider.serverUrl,
          'portalUrl': provider.serverUrl,
          'username': provider.username,
          'password': provider.password,
          'macAddress': provider.macAddress,
        };
      },
    );
    Get.put<StreamEngine>(streamEngine, permanent: true);

    Get.put<StreamRepository>(
      StreamRepositoryImpl(streamEngine),
      permanent: true,
    );
    Get.put<AuthenticationRepository>(
      AuthenticationRepositoryImpl(sessionManager),
      permanent: true,
    );
    Get.put<StreamCacheRepository>(
      StreamCacheRepositoryImpl(
        Get.find<StreamCache>(),
        Get.find<SessionCache>(),
      ),
      permanent: true,
    );

    Get.put<SessionController>(
      SessionController(
        authenticationRepository: Get.find<AuthenticationRepository>(),
        streamCacheRepository: Get.find<StreamCacheRepository>(),
        streamRepository: Get.find<StreamRepository>(),
        logger: Get.find<LoggingService>(),
      ),
      permanent: true,
    );
    Get.put<PlaybackSessionController>(
      PlaybackSessionController(
        streamRepository: Get.find<StreamRepository>(),
        logger: Get.find<LoggingService>(),
      ),
      permanent: true,
    );
    Get.put<StreamHealthController>(
      StreamHealthController(streamEngine),
      permanent: true,
    );
    Get.put<AuthenticationController>(
      AuthenticationController(
        authenticationRepository: Get.find<AuthenticationRepository>(),
        authenticationEngine: authEngine,
        logger: Get.find<LoggingService>(),
      ),
      permanent: true,
    );
  }
}
