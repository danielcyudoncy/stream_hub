import 'dart:async';

import 'package:get/get.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/logging/logging_service.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/validators.dart';
import './constants/auth_constants.dart';
import './models/user_model.dart';
import './repositories/auth_repository.dart';

class AuthController extends GetxController {
  final AuthRepository? _repository;
  final LoggingService _logger = Get.find<LoggingService>();

  AuthController({AuthRepository? repository}) : _repository = repository;

  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isAuthenticated = false.obs;
  final RxBool rememberMe = false.obs;
  final RxString lastEmail = ''.obs;
  final RxBool hasAttemptedAnonymousLogin = false.obs;

  final RxBool _didInitialize = false.obs;
  StreamSubscription<UserModel?>? _userSubscription;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _repository?.initialize();
    } catch (e) {
      // continue without auth initialization
    }
    _loadLocalState();
    _setupAuthListener();
    _didInitialize.value = true;
  }

  @override
  void onClose() {
    _userSubscription?.cancel();
    _userSubscription = null;
    super.onClose();
  }

  void _loadLocalState() {
    if (_repository == null) return;
    rememberMe.value = _repository.getRememberMe();
    final email = _repository.getLastEmail();
    if (email != null) lastEmail.value = email;
  }

  void _setupAuthListener() {
    _userSubscription?.cancel();
    _userSubscription = null;
    if (_repository != null) {
      _userSubscription = _repository.getCurrentUserStream().listen(
        (UserModel? user) {
          if (_didInitialize.value) {
            if (user != null) {
              currentUser.value = user;
              isAuthenticated.value = true;
              Get.offAllNamed(AppRoutes.home);
            } else {
              currentUser.value = null;
              isAuthenticated.value = false;
            }
          }
        },
        onError: (error) {
          errorMessage.value =
              'Authentication stream error: ${error.toString()}';
        },
      );
    }
  }

  Future<void> initialize() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      if (_repository == null) {
        isAuthenticated.value = false;
        return;
      }
      final user = await _repository.tryAutoLogin();
      if (user != null && rememberMe.value) {
        currentUser.value = user;
        isAuthenticated.value = true;
        Get.offAllNamed(AppRoutes.home);
      } else if (user != null) {
        currentUser.value = user;
        isAuthenticated.value = true;
        Get.offAllNamed(AppRoutes.home);
      } else {
        isAuthenticated.value = false;
      }
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value =
          'An unexpected error occurred during initialization.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loginWithEmail(String email, String password) async {
    if (isLoading.value) return;
    if (!Validators.isValidEmail(email)) {
      errorMessage.value = 'Please enter a valid email address.';
      return;
    }
    if (password.isEmpty) {
      errorMessage.value = 'Please enter your password.';
      return;
    }
    if (_repository == null) {
      errorMessage.value = 'Authentication service is not available.';
      return;
    }
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final user = await _repository.loginWithEmail(email, password);
      currentUser.value = user;
      isAuthenticated.value = true;
      await _repository.setRememberMe(rememberMe.value);
      if (rememberMe.value) {
        final expiry = DateTime.now().add(AuthConstants.sessionDuration);
        await _repository.setSessionExpiry(expiry);
      }
      Get.offAllNamed(AppRoutes.home);
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'An unexpected error occurred. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
    required bool acceptedTerms,
  }) async {
    if (isLoading.value) return;
    if (fullName.trim().length < AuthConstants.minNameLength) {
      errorMessage.value =
          'Full name must be at least ${AuthConstants.minNameLength} characters.';
      return;
    }
    if (!Validators.isValidEmail(email)) {
      errorMessage.value = 'Please enter a valid email address.';
      return;
    }
    if (password.length < AuthConstants.minPasswordLength) {
      errorMessage.value =
          'Password must be at least ${AuthConstants.minPasswordLength} characters.';
      return;
    }
    if (password != confirmPassword) {
      errorMessage.value = 'Passwords do not match.';
      return;
    }
    if (!acceptedTerms) {
      errorMessage.value = 'You must accept the terms and conditions.';
      return;
    }
    if (_repository == null) {
      errorMessage.value = 'Authentication service is not available.';
      return;
    }
    try {
      _logger.info('RegisterWithEmail invoked', tag: 'AuthController');
      isLoading.value = true;
      errorMessage.value = '';
      final user = await _repository.registerWithEmail(
        email: email,
        password: password,
        fullName: fullName,
      );
      _logger.info(
        'RegisterWithEmail successful for ${user.id}',
        tag: 'AuthController',
      );
      currentUser.value = user;
      isAuthenticated.value = true;
      Get.offAllNamed(AppRoutes.emailVerification);
    } on ApplicationException catch (e) {
      _logger.warning(
        'RegisterWithEmail ApplicationException: ${e.message}',
        tag: 'AuthController',
        error: e,
      );
      errorMessage.value = e.message;
    } catch (e) {
      _logger.error(
        'RegisterWithEmail unexpected error',
        tag: 'AuthController',
        error: e,
      );
      errorMessage.value = 'An unexpected error occurred. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loginWithGoogle() async {
    if (isLoading.value) return;
    if (_repository == null) {
      errorMessage.value = 'Authentication service is not available.';
      return;
    }
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final user = await _repository.signInWithGoogle();
      currentUser.value = user;
      isAuthenticated.value = true;
      Get.offAllNamed(AppRoutes.home);
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'An unexpected error occurred. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loginAnonymously() async {
    if (isLoading.value) return;
    if (hasAttemptedAnonymousLogin.value) return;
    hasAttemptedAnonymousLogin.value = true;
    if (_repository == null) {
      errorMessage.value = 'Authentication service is not available.';
      return;
    }
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final user = await _repository.signInAnonymously();
      currentUser.value = user;
      isAuthenticated.value = true;
      Get.offAllNamed(AppRoutes.home);
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'An unexpected error occurred. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    if (!Validators.isValidEmail(email)) {
      errorMessage.value = 'Please enter a valid email address.';
      return;
    }
    if (_repository == null) {
      errorMessage.value = 'Authentication service is not available.';
      return;
    }
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _repository.sendPasswordResetEmail(email);
      Get.back();
      Get.snackbar(
        'Reset Email Sent',
        'Please check your inbox for password reset instructions.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.surface,
        colorText: Get.theme.colorScheme.onSurface,
      );
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'An unexpected error occurred. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendVerificationEmail() async {
    if (_repository == null) {
      errorMessage.value = 'Authentication service is not available.';
      return;
    }
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _repository.sendEmailVerification();
      Get.snackbar(
        'Verification Email Sent',
        'Please check your inbox and verify your email address.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.surface,
        colorText: Get.theme.colorScheme.onSurface,
      );
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'An unexpected error occurred. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshVerificationStatus() async {
    if (_repository == null) {
      errorMessage.value = 'Authentication service is not available.';
      return;
    }
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _repository.reloadUser();
      final user = await _repository.getCurrentUser();
      if (user != null) {
        currentUser.value = user;
        if (user.emailVerified) {
          Get.offAllNamed(AppRoutes.completeProfile);
        } else {
          errorMessage.value =
              'Email is not yet verified. Please check your inbox.';
        }
      }
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'An unexpected error occurred. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      if (_repository != null) {
        await _repository.logout();
      }
      currentUser.value = null;
      isAuthenticated.value = false;
      Get.offAllNamed(AppRoutes.login);
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'An unexpected error occurred during logout.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> continueAfterVerification() async {
    if (_repository == null) {
      errorMessage.value = 'Authentication service is not available.';
      return;
    }
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _repository.reloadUser();
      final user = await _repository.getCurrentUser();
      if (user != null) {
        currentUser.value = user;
        if (user.emailVerified) {
          Get.offAllNamed(AppRoutes.completeProfile);
        } else {
          errorMessage.value =
              'Email is not yet verified. Please verify your email to continue.';
        }
      }
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'An unexpected error occurred. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  void clearError() {
    errorMessage.value = '';
  }
}
