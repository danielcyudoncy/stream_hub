import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'media_binding.dart';
import 'stream_engine_binding.dart';
import 'iptv_core_binding.dart';
import 'package:stream_hub/data/repositories/settings_repository.dart';
import 'package:stream_hub/data/repositories/profile_repository.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/catalog_repository_impl.dart';
import 'package:stream_hub/data/repositories/media_repository.dart';
import 'package:stream_hub/data/repositories/media_repository_impl.dart';
import 'package:stream_hub/data/repositories/history_repository.dart';
import 'package:stream_hub/data/repositories/history_repository_impl.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository_impl.dart';
import 'package:stream_hub/data/services/history_service.dart';
import 'package:stream_hub/data/services/favorite_service.dart';
import 'package:stream_hub/data/services/settings_service.dart';
import 'package:stream_hub/data/services/profile_service.dart';
import 'package:stream_hub/data/services/provider_storage_service.dart';
import 'package:stream_hub/data/services/cache_service.dart';
import 'package:stream_hub/data/services/database_service.dart';
import 'package:stream_hub/data/services/firebase_service.dart';
import 'package:stream_hub/data/services/provider_sync_service.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/media/media_catalog.dart';
import 'package:stream_hub/core/media/media_source_manager.dart';
import 'package:stream_hub/core/media/media_source_factory.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/repositories/media_source_repository.dart';
import 'package:stream_hub/modules/live_tv/controllers/live_tv_home_controller.dart';
import 'package:stream_hub/modules/live_tv/controllers/live_tv_controller.dart';
import 'package:stream_hub/modules/live_tv/controllers/category_controller.dart';
import 'package:stream_hub/modules/live_tv/controllers/favorites_controller.dart';
import 'package:stream_hub/modules/live_tv/controllers/provider_controller.dart';
import 'package:stream_hub/modules/live_tv/controllers/live_tv_library_controller.dart';
import 'package:stream_hub/modules/authentication/services/auth_service.dart';
import 'package:stream_hub/modules/authentication/services/auth_local_storage_service.dart';
import 'package:stream_hub/modules/authentication/repositories/auth_repository.dart';
import 'package:stream_hub/modules/authentication/auth_controller.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    StreamEngineBinding().dependencies();
    IptvCoreBinding().dependencies();
    MediaBinding().dependencies();
    Get.find<DatabaseService>();
    final settingsRepo = SettingsRepository();
    final profileRepo = ProfileRepository();
    final providerRepo = ProviderRepository();

    Get.put<SettingsRepository>(settingsRepo, permanent: true);
    Get.put<ProfileRepository>(profileRepo, permanent: true);
    Get.put<ProviderRepository>(providerRepo, permanent: true);

    Get.put<SettingsService>(SettingsService(settingsRepo), permanent: true);
    Get.put<ProfileService>(ProfileService(profileRepo), permanent: true);
    Get.put<ProviderStorageService>(ProviderStorageService(providerRepo), permanent: true);
    Get.put<CacheService>(CacheService(settingsRepo), permanent: true);

    final mediaCatalog = Get.find<MediaCatalog>();
    final mediaSourceManager = Get.find<MediaSourceManager>();
    final loggingService = Get.find<LoggingService>();
    Get.find<MediaSourceRepository>();

    final catalogRepo = CatalogRepositoryImpl(
      mediaCatalog,
      mediaSourceManager,
      loggingService,
    );
    final mediaRepo = MediaRepositoryImpl(mediaCatalog);

    Get.put<CatalogRepository>(catalogRepo, permanent: true);
    Get.put<MediaRepository>(mediaRepo, permanent: true);

    Get.put<ProviderSyncService>(
      ProviderSyncService(
        repository: providerRepo,
        sourceFactory: Get.find<MediaSourceFactory>(),
        sourceRepo: Get.find<MediaSourceRepository>(),
        catalogRepo: catalogRepo,
        logger: loggingService,
      ),
      permanent: true,
    );

    final databaseService = Get.find<DatabaseService>();
    Box? favBox;
    try {
      favBox = databaseService.favoritesBox;
    } catch (_) {}

    Get.put<HistoryService>(HistoryService(logger: loggingService), permanent: true);
    Get.put<FavoriteService>(
      FavoriteService(logger: loggingService, box: favBox),
      permanent: true,
    );
    Get.put<HistoryRepository>(HistoryRepositoryImpl(Get.find<HistoryService>()), permanent: true);
    final favoriteRepo = FavoriteRepositoryImpl(Get.find<FavoriteService>(), catalogRepo);
    Get.put<FavoriteRepository>(favoriteRepo, permanent: true);

    Get.put<LiveTVHomeController>(
      LiveTVHomeController(
        mediaEngine: Get.find<MediaEngine>(),
        mediaLibrary: Get.find<MediaLibrary>(),
        catalogRepository: catalogRepo,
        favoriteRepository: favoriteRepo,
      ),
      permanent: true,
    );

    Get.put<LiveTVController>(
      LiveTVController(
        mediaEngine: Get.find<MediaEngine>(),
        mediaLibrary: Get.find<MediaLibrary>(),
        catalogRepository: catalogRepo,
        favoriteRepository: favoriteRepo,
      ),
      permanent: true,
    );
    Get.put<CategoryController>(
      CategoryController(
        mediaEngine: Get.find<MediaEngine>(),
        mediaLibrary: Get.find<MediaLibrary>(),
        catalogRepository: catalogRepo,
        favoriteRepository: favoriteRepo,
      ),
      permanent: true,
    );
    Get.put<FavoritesController>(
      FavoritesController(
        mediaEngine: Get.find<MediaEngine>(),
        mediaLibrary: Get.find<MediaLibrary>(),
        catalogRepository: catalogRepo,
        favoriteRepository: favoriteRepo,
      ),
      permanent: true,
    );
    Get.put<ProviderController>(
      ProviderController(
        mediaEngine: Get.find<MediaEngine>(),
        mediaLibrary: Get.find<MediaLibrary>(),
        catalogRepository: catalogRepo,
        favoriteRepository: favoriteRepo,
      ),
      permanent: true,
    );
    Get.put<LiveTVLibraryController>(
      LiveTVLibraryController(
        mediaEngine: Get.find<MediaEngine>(),
        mediaLibrary: Get.find<MediaLibrary>(),
        catalogRepository: catalogRepo,
        favoriteRepository: favoriteRepo,
      ),
      permanent: true,
    );

    if (!Get.isRegistered<FirebaseService>()) {
      Get.put<FirebaseService>(FirebaseService(), permanent: true);
    }

    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<AuthLocalStorageService>()) {
      Get.put<AuthLocalStorageService>(
        AuthLocalStorageService(),
        permanent: true,
      );
    }
    if (!Get.isRegistered<AuthRepository>()) {
      final firebaseService = Get.isRegistered<FirebaseService>()
          ? Get.find<FirebaseService>()
          : null;
      Get.put<AuthRepository>(
        AuthRepository(
          authService: Get.find<AuthService>(),
          localStorage: Get.find<AuthLocalStorageService>(),
          firebaseService: firebaseService,
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<AuthController>()) {
      final repository = Get.isRegistered<AuthRepository>()
          ? Get.find<AuthRepository>()
          : null;
      Get.lazyPut<AuthController>(
        () => AuthController(repository: repository),
        fenix: true,
      );
    }
  }
}