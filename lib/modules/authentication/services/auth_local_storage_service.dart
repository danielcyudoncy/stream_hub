import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/logging/logging_service.dart';
import '../constants/auth_constants.dart';

class AuthLocalStorageService extends GetxService {
  final LoggingService _logger = Get.find<LoggingService>();

  late Box _box;

  Future<AuthLocalStorageService> init() async {
    _logger.info('Initializing AuthLocalStorageService...', tag: 'AuthLocalStorage');
    _box = await _openBoxSafe(AuthConstants.boxAuth);
    _logger.info('AuthLocalStorageService initialized.', tag: 'AuthLocalStorage');
    return this;
  }

  Future<Box> _openBoxSafe(String name) async {
    try {
      return await Hive.openBox(name);
    } catch (e) {
      _logger.warning('Failed to open box: $name. Recovering...', tag: 'AuthLocalStorage', error: e);
      await Hive.deleteBoxFromDisk(name);
      return await Hive.openBox(name);
    }
  }

  String? getLastEmail() {
    try {
      final value = _box.get(AuthConstants.keyLastEmail);
      if (value is String && value.isNotEmpty) return value;
      return null;
    } catch (e) {
      _logger.warning('Failed to read last email', tag: 'AuthLocalStorage', error: e);
      return null;
    }
  }

  Future<void> saveLastEmail(String email) async {
    try {
      await _box.put(AuthConstants.keyLastEmail, email.trim());
    } catch (e) {
      _logger.warning('Failed to save last email', tag: 'AuthLocalStorage', error: e);
    }
  }

  String? getPreferredLoginMethod() {
    try {
      final value = _box.get(AuthConstants.keyPreferredLoginMethod);
      if (value is String && value.isNotEmpty) return value;
      return null;
    } catch (e) {
      _logger.warning('Failed to read preferred login method', tag: 'AuthLocalStorage', error: e);
      return null;
    }
  }

  Future<void> savePreferredLoginMethod(String method) async {
    try {
      await _box.put(AuthConstants.keyPreferredLoginMethod, method);
    } catch (e) {
      _logger.warning('Failed to save preferred login method', tag: 'AuthLocalStorage', error: e);
    }
  }

  bool getRememberMe() {
    try {
      final value = _box.get(AuthConstants.keyRememberMe);
      return value is bool ? value : false;
    } catch (e) {
      _logger.warning('Failed to read remember me preference', tag: 'AuthLocalStorage', error: e);
      return false;
    }
  }

  Future<void> saveRememberMe(bool value) async {
    try {
      await _box.put(AuthConstants.keyRememberMe, value);
    } catch (e) {
      _logger.warning('Failed to save remember me preference', tag: 'AuthLocalStorage', error: e);
    }
  }

  DateTime? getSessionExpiry() {
    try {
      final value = _box.get(AuthConstants.keySessionExpiresAt);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    } catch (e) {
      _logger.warning('Failed to read session expiry', tag: 'AuthLocalStorage', error: e);
      return null;
    }
  }

  Future<void> saveSessionExpiry(DateTime expiry) async {
    try {
      await _box.put(AuthConstants.keySessionExpiresAt, expiry.millisecondsSinceEpoch);
    } catch (e) {
      _logger.warning('Failed to save session expiry', tag: 'AuthLocalStorage', error: e);
    }
  }

  bool isSessionValid() {
    final expiry = getSessionExpiry();
    if (expiry == null) return false;
    return DateTime.now().isBefore(expiry);
  }

  Future<void> clearAuthSession() async {
    try {
      await _box.delete(AuthConstants.keyLastEmail);
      await _box.delete(AuthConstants.keyPreferredLoginMethod);
      await _box.delete(AuthConstants.keyRememberMe);
      await _box.delete(AuthConstants.keySessionExpiresAt);
      _logger.info('Auth session cleared.', tag: 'AuthLocalStorage');
    } catch (e) {
      _logger.warning('Failed to clear auth session', tag: 'AuthLocalStorage', error: e);
    }
  }
}
