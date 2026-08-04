import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:get/get.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/logging/logging_service.dart';
import '../../../data/services/firebase_service.dart';
import '../models/user_model.dart';

class AuthService extends GetxService {
  final LoggingService _logger = Get.find<LoggingService>();
  final FirebaseService? _firebaseService = Get.isRegistered<FirebaseService>() ? Get.find<FirebaseService>() : null;
  GoogleSignIn? _googleSignIn;

  firebase_auth.FirebaseAuth? _auth;
  bool _authInitialized = false;

  GoogleSignIn get _googleSignInInstance {
    _googleSignIn ??= GoogleSignIn();
    return _googleSignIn!;
  }

  bool get isFirebaseAvailable => _firebaseService?.isAvailable ?? false;
  firebase_auth.User? get _firebaseUser => _auth?.currentUser;

  Future<AuthService> init() async {
    _logger.info('Initializing AuthService...', tag: 'AuthService');
    if (!isFirebaseAvailable) {
      _logger.warning('AuthService running in limited mode (Firebase unavailable).', tag: 'AuthService');
      return this;
    }
    try {
      _auth = firebase_auth.FirebaseAuth.instance;
      _authInitialized = true;
      _auth!.authStateChanges().listen((user) {
        _logger.info('Auth state changed: ${user?.uid ?? "signed_out"}', tag: 'AuthService');
      });
    } catch (e) {
      _logger.error('Failed to initialize FirebaseAuth', tag: 'AuthService', error: e);
      _auth = null;
      _authInitialized = false;
    }
    return this;
  }

  bool get isAuthenticated => _authInitialized && _firebaseUser != null;

  bool get _isReady => isFirebaseAvailable && _authInitialized && _auth != null;

  Future<UserModel?> getCurrentUser() async {
    if (!_isReady) return null;
    try {
      final user = _auth!.currentUser;
      if (user == null) return null;
      await user.reload();
      final refreshed = _auth!.currentUser;
      if (refreshed == null) return null;
      return _mapFirebaseUser(refreshed);
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.error('Failed to get current user', tag: 'AuthService', error: e);
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      _logger.error('Unexpected error getting current user', tag: 'AuthService', error: e);
      throw UnknownException(originalError: e);
    }
  }

  /// Returns the locally persisted Firebase user without a network refresh.
  ///
  /// Used during cold-start session restoration so authentication never blocks
  /// startup or depends on connectivity (offline-first principle). The user may
  /// be stale until a later explicit refresh.
  Future<UserModel?> getCachedCurrentUser() async {
    if (!_isReady) return null;
    final user = _auth!.currentUser;
    if (user == null) return null;
    return _mapFirebaseUser(user);
  }

  Future<UserModel> loginWithEmail(String email, String password) async {
    if (!_isReady) {
      throw const AuthenticationException(message: 'Firebase is unavailable. Please try again later.');
    }
    try {
      _logger.info('Attempting email login for: $email', tag: 'AuthService');
      final credential = await _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthenticationException(message: 'Login failed. Please try again.');
      }
      _logger.info('Email login successful for: ${user.uid}', tag: 'AuthService');
      return _mapFirebaseUser(user);
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.error('Email login failed', tag: 'AuthService', error: e);
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      _logger.error('Unexpected error during email login', tag: 'AuthService', error: e);
      throw UnknownException(originalError: e);
    }
  }

  Future<UserModel> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (!_isReady) {
      throw const AuthenticationException(message: 'Firebase is unavailable. Please try again later.');
    }
    try {
      _logger.info('Attempting registration for: $email', tag: 'AuthService');
      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthenticationException(message: 'Registration failed. Please try again.');
      }
      await user.updateDisplayName(fullName.trim());
      await user.sendEmailVerification();
      _logger.info('Registration successful for: ${user.uid}', tag: 'AuthService');
      return _mapFirebaseUser(user);
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.error('Registration failed', tag: 'AuthService', error: e);
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      _logger.error('Unexpected error during registration', tag: 'AuthService', error: e);
      throw UnknownException(originalError: e);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (!_isReady) {
      throw const AuthenticationException(message: 'Firebase is unavailable. Please try again later.');
    }
    try {
      _logger.info('Sending password reset email to: $email', tag: 'AuthService');
      await _auth!.sendPasswordResetEmail(email: email.trim());
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.error('Password reset failed', tag: 'AuthService', error: e);
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      _logger.error('Unexpected error during password reset', tag: 'AuthService', error: e);
      throw UnknownException(originalError: e);
    }
  }

  Future<UserModel> signInWithGoogle() async {
    if (!_isReady) {
      throw const AuthenticationException(message: 'Firebase is unavailable. Please try again later.');
    }
    try {
      _logger.info('Attempting Google Sign-In...', tag: 'AuthService');
      final GoogleSignInAccount? googleUser = await _googleSignInInstance.signIn();
      if (googleUser == null) {
        throw const AuthenticationException(message: 'Google Sign-In was cancelled.');
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth!.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw const AuthenticationException(message: 'Google Sign-In failed. Please try again.');
      }
      _logger.info('Google Sign-In successful for: ${user.uid}', tag: 'AuthService');
      return _mapFirebaseUser(user);
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.error('Google Sign-In failed', tag: 'AuthService', error: e);
      throw _mapFirebaseAuthException(e);
    } on SocketException catch (e) {
      _logger.error('Network error during Google Sign-In', tag: 'AuthService', error: e);
      throw NetworkException(originalError: e);
    } catch (e) {
      _logger.error('Unexpected error during Google Sign-In', tag: 'AuthService', error: e);
      if (e is AuthenticationException) rethrow;
      throw UnknownException(originalError: e);
    }
  }

  Future<UserModel> signInAnonymously() async {
    if (!_isReady) {
      throw const AuthenticationException(message: 'Firebase is unavailable. Please try again later.');
    }
    try {
      _logger.info('Attempting anonymous sign-in...', tag: 'AuthService');
      final credential = await _auth!.signInAnonymously();
      final user = credential.user;
      if (user == null) {
        throw const AuthenticationException(message: 'Anonymous sign-in failed. Please try again.');
      }
      _logger.info('Anonymous sign-in successful for: ${user.uid}', tag: 'AuthService');
      return _mapFirebaseUser(user);
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.error('Anonymous sign-in failed', tag: 'AuthService', error: e);
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      _logger.error('Unexpected error during anonymous sign-in', tag: 'AuthService', error: e);
      throw UnknownException(originalError: e);
    }
  }

  Future<void> sendEmailVerification() async {
    if (!_isReady) {
      throw const AuthenticationException(message: 'Firebase is unavailable. Please try again later.');
    }
    try {
      final user = _auth!.currentUser;
      if (user == null) {
        throw const AuthenticationException(message: 'No user is currently signed in.');
      }
      if (user.emailVerified) {
        return;
      }
      _logger.info('Sending email verification to: ${user.email}', tag: 'AuthService');
      await user.sendEmailVerification();
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.error('Failed to send verification email', tag: 'AuthService', error: e);
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      _logger.error('Unexpected error sending verification email', tag: 'AuthService', error: e);
      throw UnknownException(originalError: e);
    }
  }

  Future<void> reloadUser() async {
    if (!_isReady) return;
    try {
      final user = _auth!.currentUser;
      if (user != null) {
        await user.reload();
      }
    } catch (e) {
      _logger.warning('Failed to reload user', tag: 'AuthService', error: e);
    }
  }

  Future<void> logout() async {
    if (!_isReady) return;
    try {
      _logger.info('Logging out user...', tag: 'AuthService');
      await _googleSignInInstance.signOut();
      await _auth!.signOut();
      _logger.info('Logout successful.', tag: 'AuthService');
    } catch (e) {
      _logger.error('Error during logout', tag: 'AuthService', error: e);
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    if (!_isReady) {
      throw const AuthenticationException(message: 'Firebase is unavailable. Please try again later.');
    }
    try {
      final user = _auth!.currentUser;
      if (user == null) {
        throw const AuthenticationException(message: 'No user is currently signed in.');
      }
      _logger.info('Deleting account for: ${user.uid}', tag: 'AuthService');
      await user.delete();
      _logger.info('Account deleted successfully.', tag: 'AuthService');
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.error('Account deletion failed', tag: 'AuthService', error: e);
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      _logger.error('Unexpected error during account deletion', tag: 'AuthService', error: e);
      throw UnknownException(originalError: e);
    }
  }

  UserModel _mapFirebaseUser(firebase_auth.User user) {
    AuthProvider mapProvider(List<firebase_auth.UserInfo> providerData) {
      for (final info in providerData) {
        final providerId = info.providerId.toLowerCase();
        if (providerId.contains('google')) return AuthProvider.google;
        if (providerId.contains('password')) return AuthProvider.email;
        if (providerId.contains('anonymous')) return AuthProvider.anonymous;
      }
      return AuthProvider.unknown;
    }

    return UserModel(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      provider: mapProvider(user.providerData),
      emailVerified: user.emailVerified,
      createdAt: (user.metadata.creationTime ?? DateTime.now()).toUtc(),
      lastLogin: (user.metadata.lastSignInTime ?? DateTime.now()).toUtc(),
    );
  }

  ApplicationException _mapFirebaseAuthException(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return AuthenticationException(message: 'The email address is not valid.', code: e.code);
      case 'user-disabled':
        return AuthenticationException(message: 'This user account has been disabled.', code: e.code);
      case 'user-not-found':
        return AuthenticationException(message: 'No user found with this email.', code: e.code);
      case 'wrong-password':
        return AuthenticationException(message: 'Incorrect password. Please try again.', code: e.code);
      case 'email-already-in-use':
        return AuthenticationException(message: 'An account already exists with this email.', code: e.code);
      case 'invalid-credential':
        return AuthenticationException(message: 'Invalid credentials. Please check and try again.', code: e.code);
      case 'operation-not-allowed':
        return AuthenticationException(message: 'This sign-in method is not enabled.', code: e.code);
      case 'weak-password':
        return AuthenticationException(message: 'The password is too weak.', code: e.code);
      case 'too-many-requests':
        return AuthenticationException(message: 'Too many attempts. Please wait and try again later.', code: e.code);
      case 'network-request-failed':
        return NetworkException(message: 'Network error. Please check your connection.', code: e.code);
      case 'requires-recent-login':
        return AuthenticationException(message: 'Please log in again to complete this action.', code: e.code);
      case 'invalid-action-code':
        return AuthenticationException(message: 'The action code is invalid or expired.', code: e.code);
      default:
        return AuthenticationException(message: e.message ?? 'An authentication error occurred.', code: e.code);
    }
  }
}
