import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import '../../core/logging/logging_service.dart';

class FirebaseService extends GetxService {
  final LoggingService _logger = Get.find<LoggingService>();
  bool _isAvailable = false;

  bool get isAvailable => _isAvailable;

  Future<FirebaseService> init() async {
    _logger.info('Initializing Firebase services...', tag: 'FirebaseService');
    try {
      // Attempt Firebase initialization
      await Firebase.initializeApp();
      _isAvailable = true;
      _logger.info('Firebase initialization successful.', tag: 'FirebaseService');
    } catch (e) {
      _isAvailable = false;
      _logger.warning(
        'Firebase is unavailable (missing credentials, config files, or offline). '
        'Application will operate in local/cached mode.',
        tag: 'FirebaseService',
        error: e,
      );
    }
    return this;
  }
}
