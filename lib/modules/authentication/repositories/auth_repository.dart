import 'dart:async';

import 'package:get/get.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/logging/logging_service.dart';
import '../../../data/services/firebase_service.dart';
import '../constants/auth_constants.dart';
import '../models/user_model.dart';
import '../services/auth_local_storage_service.dart';
import '../services/auth_service.dart';

class AuthRepository extends GetxService {
  final AuthService _authService;
  final AuthLocalStorageService _localStorage;
  final FirebaseService? _firebaseService;

  final StreamController<UserModel?> _userStreamController =
      StreamController<UserModel?>.broadcast();

  AuthRepository({
    required AuthService authService,
    required AuthLocalStorageService localStorage,
    FirebaseService? firebaseService,
  }) : _authService = authService,
        _localStorage = localStorage,
        _firebaseService = firebaseService;

  final LoggingService _logger = Get.find<LoggingService>();
  bool _initialized = false;

  Stream<UserModel?> getCurrentUserStream() => _userStreamController.stream;

  bool get isFirebaseAvailable => _firebaseService?.isAvailable ?? false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _authService.init();
    await _localStorage.init();
    _initialized = true;
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final user = await _authService.getCurrentUser();
      return user;
    } on ApplicationException {
      rethrow;
    } catch (e) {
      throw UnknownException(originalError: e);
    }
  }

  Future<UserModel> loginWithEmail(String email, String password) async {
    try {
      final user = await _authService.loginWithEmail(email, password);
      await _localStorage.saveLastEmail(email);
      await _localStorage.savePreferredLoginMethod('email');
      return user;
    } on ApplicationException {
      rethrow;
    } catch (e) {
      throw UnknownException(originalError: e);
    }
  }

  Future<UserModel> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      _logger.info(
        'AuthRepository.registerWithEmail: starting for $email',
        tag: 'AuthRepository',
      );
      final user = await _authService.registerWithEmail(
        email: email,
        password: password,
        fullName: fullName,
      );
      _logger.info(
        'AuthRepository.registerWithEmail: success for ${user.id}',
        tag: 'AuthRepository',
      );
      await _localStorage.saveLastEmail(email);
      await _localStorage.savePreferredLoginMethod('email');
      return user;
    } on ApplicationException {
      _logger.warning(
        'AuthRepository.registerWithEmail: application exception for $email',
        tag: 'AuthRepository',
      );
      rethrow;
    } catch (e) {
      _logger.error(
        'AuthRepository.registerWithEmail: unexpected error for $email',
        tag: 'AuthRepository',
        error: e,
      );
      throw UnknownException(originalError: e);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
    } on ApplicationException {
      rethrow;
    } catch (e) {
      throw UnknownException(originalError: e);
    }
  }

  Future<UserModel> signInWithGoogle() async {
    try {
      final user = await _authService.signInWithGoogle();
      await _localStorage.savePreferredLoginMethod('google');
      return user;
    } on ApplicationException {
      rethrow;
    } catch (e) {
      throw UnknownException(originalError: e);
    }
  }

  Future<UserModel> signInAnonymously() async {
    try {
      final user = await _authService.signInAnonymously();
      await _localStorage.savePreferredLoginMethod('anonymous');
      return user;
    } on ApplicationException {
      rethrow;
    } catch (e) {
      throw UnknownException(originalError: e);
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
    } on ApplicationException {
      rethrow;
    } catch (e) {
      throw UnknownException(originalError: e);
    }
  }

  Future<void> reloadUser() async {
    try {
      await _authService.reloadUser();
    } catch (e) {
      throw UnknownException(originalError: e);
    }
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
      await _localStorage.clearAuthSession();
    } catch (e) {
      throw UnknownException(originalError: e);
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _authService.deleteAccount();
      await _localStorage.clearAuthSession();
    } on ApplicationException {
      rethrow;
    } catch (e) {
      throw UnknownException(originalError: e);
    }
  }

  Future<UserModel?> tryAutoLogin() async {
    try {
      final user = await _authService.getCachedCurrentUser();
      if (user != null) {
        // Refresh local session expiry for seamless subsequent launches
        await setSessionExpiry(DateTime.now().add(AuthConstants.sessionDuration));
        return user;
      }
      if (_localStorage.isSessionValid()) {
        return await _authService.getCurrentUser();
      }
      return null;
    } catch (e) {
      _logger.warning('Auto-login check failed: $e', tag: 'AuthRepository', error: e);
      return null;
    }
  }

  Future<void> setRememberMe(bool value) async {
    await _localStorage.saveRememberMe(value);
  }

  bool getRememberMe() => _localStorage.getRememberMe();

  String? getLastEmail() => _localStorage.getLastEmail();

  Future<void> setSessionExpiry(DateTime expiry) async {
    await _localStorage.saveSessionExpiry(expiry);
  }

  @override
  void onClose() {
    _userStreamController.close();
    super.onClose();
  }
}
