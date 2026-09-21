import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/modules/authentication/auth_controller.dart';
import 'package:stream_hub/modules/authentication/models/user_model.dart';
import 'package:stream_hub/modules/authentication/repositories/auth_repository.dart';
import 'package:stream_hub/modules/authentication/services/auth_local_storage_service.dart';
import 'package:stream_hub/modules/authentication/services/auth_service.dart';

class _FakeAuthLocalStorageService extends AuthLocalStorageService {
  bool _rememberMe = false;
  String? _lastEmail;
  String? _preferredMethod;
  DateTime? _expiry;

  @override
  Future<AuthLocalStorageService> init() async => this;

  @override
  bool getRememberMe() => _rememberMe;

  @override
  Future<void> saveRememberMe(bool value) async {
    _rememberMe = value;
  }

  @override
  String? getLastEmail() => _lastEmail;

  @override
  Future<void> saveLastEmail(String email) async {
    _lastEmail = email;
  }

  @override
  String? getPreferredLoginMethod() => _preferredMethod;

  @override
  Future<void> savePreferredLoginMethod(String method) async {
    _preferredMethod = method;
  }

  @override
  DateTime? getSessionExpiry() => _expiry;

  @override
  Future<void> saveSessionExpiry(DateTime expiry) async {
    _expiry = expiry;
  }

  @override
  bool isSessionValid() {
    if (_expiry == null) return false;
    return DateTime.now().isBefore(_expiry!);
  }

  @override
  Future<void> clearAuthSession() async {
    _lastEmail = null;
    _preferredMethod = null;
    _rememberMe = false;
    _expiry = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
    Get.put<LoggingService>(LoggingService(), permanent: true);
  });

  tearDown(() {
    Get.reset();
  });

  group('Offline Authentication Fallback Tests', () {
    test('AuthService returns local session when Firebase is unavailable', () async {
      final authService = AuthService();
      await authService.init(); // Inits with Firebase unavailable

      expect(authService.isFirebaseAvailable, isFalse);

      final emailUser = await authService.loginWithEmail('streamer@test.com', 'pass123');
      expect(emailUser.email, 'streamer@test.com');
      expect(emailUser.id, startsWith('local_'));
      expect(emailUser.provider, AuthProvider.email);

      final regUser = await authService.registerWithEmail(
        email: 'newuser@test.com',
        password: 'password123',
        fullName: 'Test User',
      );
      expect(regUser.email, 'newuser@test.com');
      expect(regUser.displayName, 'Test User');

      final guestUser = await authService.signInAnonymously();
      expect(guestUser.id, 'guest_local');
      expect(guestUser.provider, AuthProvider.anonymous);

      final googleUser = await authService.signInWithGoogle();
      expect(googleUser.id, 'local_google_user');
      expect(googleUser.provider, AuthProvider.google);
    });

    test('AuthController authenticates successfully in offline mode', () async {
      final authService = AuthService();
      await authService.init();

      final localStorage = _FakeAuthLocalStorageService();
      await localStorage.init();

      final repo = AuthRepository(
        authService: authService,
        localStorage: localStorage,
      );
      await repo.initialize();

      final controller = AuthController(repository: repo);
      Get.put<AuthController>(controller);

      expect(controller.isAuthenticated.value, isFalse);

      await controller.loginAnonymously();
      expect(controller.isAuthenticated.value, isTrue);
      expect(controller.currentUser.value?.id, 'guest_local');
    });
  });
}
