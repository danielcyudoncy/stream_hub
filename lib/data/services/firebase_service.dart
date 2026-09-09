import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import '../../core/logging/logging_service.dart';
import '../../firebase_options.dart';

class FirebaseService extends GetxService {
  final LoggingService _logger = Get.find<LoggingService>();
  bool _isAvailable = false;
  bool _initialized = false;

  bool get isAvailable => _isAvailable;

  Future<FirebaseService> init() async {
    // Idempotent: Firebase is initialized in main() before runApp and again in
    // the splash bootstrap, so repeated calls must not log/re-init redundantly.
    if (_initialized) return this;
    _logger.info('Initializing Firebase services...', tag: 'FirebaseService');
    try {
      // Attempt Firebase initialization
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isAvailable = true;
      _initialized = true;
      _logger.info('Firebase initialization successful.', tag: 'FirebaseService');
    } catch (e) {
      _isAvailable = false;
      _initialized = true;
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
