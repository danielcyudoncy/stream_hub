import 'package:get/get.dart';
import 'media_binding.dart';
import 'package:stream_hub/data/repositories/settings_repository.dart';
import 'package:stream_hub/data/repositories/profile_repository.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/catalog_repository_impl.dart';
import 'package:stream_hub/data/repositories/media_repository.dart';
import 'package:stream_hub/data/repositories/media_repository_impl.dart';
import 'package:stream_hub/data/services/settings_service.dart';
import 'package:stream_hub/data/services/profile_service.dart';
import 'package:stream_hub/data/services/provider_storage_service.dart';
import 'package:stream_hub/data/services/cache_service.dart';
import 'package:stream_hub/data/services/database_service.dart';
import 'package:stream_hub/data/services/firebase_service.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/media/media_catalog.dart';
import 'package:stream_hub/core/media/media_source_manager.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/modules/live_tv/controllers/home_controller.dart';
import 'package:stream_hub/modules/live_tv/controllers/live_tv_controller.dart';
import 'package:stream_hub/modules/live_tv/controllers/category_controller.dart';
import 'package:stream_hub/modules/live_tv/controllers/favorites_controller.dart';
import 'package:stream_hub/modules/live_tv/controllers/provider_controller.dart';
import 'package:stream_hub/modules/live_tv/controllers/library_controller.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
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

    final catalogRepo = CatalogRepositoryImpl(
      mediaCatalog,
      mediaSourceManager,
      loggingService,
    );
    final mediaRepo = MediaRepositoryImpl(mediaCatalog);

    Get.put<CatalogRepository>(catalogRepo, permanent: true);
    Get.put<MediaRepository>(mediaRepo, permanent: true);

    Get.put<HomeController>(
      HomeController(
        mediaEngine: Get.find<MediaEngine>(),
        mediaLibrary: Get.find<MediaLibrary>(),
        catalogRepository: catalogRepo,
      ),
      permanent: true,
    );
    Get.put<LiveTVController>(
      LiveTVController(
        mediaEngine: Get.find<MediaEngine>(),
        mediaLibrary: Get.find<MediaLibrary>(),
        catalogRepository: catalogRepo,
      ),
      permanent: true,
    );
    Get.put<CategoryController>(
      CategoryController(
        mediaEngine: Get.find<MediaEngine>(),
        mediaLibrary: Get.find<MediaLibrary>(),
        catalogRepository: catalogRepo,
      ),
      permanent: true,
    );
    Get.put<FavoritesController>(
      FavoritesController(
        mediaEngine: Get.find<MediaEngine>(),
        mediaLibrary: Get.find<MediaLibrary>(),
        catalogRepository: catalogRepo,
      ),
      permanent: true,
    );
    Get.put<ProviderController>(
      ProviderController(
        mediaEngine: Get.find<MediaEngine>(),
        mediaLibrary: Get.find<MediaLibrary>(),
        catalogRepository: catalogRepo,
      ),
      permanent: true,
    );
    Get.put<LibraryController>(
      LibraryController(
        mediaEngine: Get.find<MediaEngine>(),
        mediaLibrary: Get.find<MediaLibrary>(),
        catalogRepository: catalogRepo,
      ),
      permanent: true,
    );

    if (!Get.isRegistered<FirebaseService>()) {
      Get.put<FirebaseService>(FirebaseService(), permanent: true);
    }
  }
}