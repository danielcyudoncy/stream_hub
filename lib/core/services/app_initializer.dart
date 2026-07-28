import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/services/database_service.dart';
import 'package:stream_hub/data/services/settings_service.dart';

class AppInitializer extends GetxController {
  final DatabaseService _databaseService;
  final SettingsService _settingsService;
  final LoggingService _logger = Get.find<LoggingService>();

  AppInitializer({
    required DatabaseService databaseService,
    required SettingsService settingsService,
  }) : _databaseService = databaseService,
       _settingsService = settingsService;

  final RxBool isInitialized = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    initialize();
  }

  Future<void> initialize() async {
    try {
      isInitialized.value = false;
      errorMessage.value = '';

      await _databaseService.init();
      await _settingsService.loadSettings();

      isInitialized.value = true;
      _logger.info('App initialized successfully', tag: 'AppInitializer');
    } catch (e) {
      errorMessage.value = 'Failed to initialize app: $e';
      _logger.error('App initialization failed', tag: 'AppInitializer', error: e);
    }
  }
}
