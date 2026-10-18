import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/app_update_info.dart';
import '../constants/app_constants.dart';
import '../helpers/platform_helper.dart';
import '../logging/logging_service.dart';

enum AppUpdateStatus {
  idle,
  checking,
  updateAvailable,
  upToDate,
  downloading,
  downloaded,
  installing,
  error,
}

class AppUpdateService extends GetxService {
  final LoggingService? _logger;
  final FirebaseRemoteConfig? _remoteConfig;
  static const MethodChannel _platformChannel = MethodChannel('stream_hub/app_update');

  final Rx<AppUpdateStatus> status = AppUpdateStatus.idle.obs;
  final Rxn<AppUpdateInfo> updateInfo = Rxn<AppUpdateInfo>();
  final RxDouble downloadProgress = 0.0.obs;
  final RxString downloadStatusMessage = ''.obs;
  final RxString errorMessage = ''.obs;
  final RxString currentVersion = AppConstants.appVersion.obs;
  final RxInt currentBuildNumber = int.parse(AppConstants.appBuildNumber).obs;

  HttpClientRequest? _activeDownloadRequest;
  IOSink? _activeDownloadSink;
  bool _isCancelled = false;

  AppUpdateService({
    LoggingService? logger,
    FirebaseRemoteConfig? remoteConfig,
  })  : _logger = logger ?? (Get.isRegistered<LoggingService>() ? Get.find<LoggingService>() : null),
        _remoteConfig = remoteConfig;

  @override
  void onInit() {
    super.onInit();
    _loadCurrentAppInfo();
  }

  Future<void> _loadCurrentAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion.value = info.version;
      final parsedBuild = int.tryParse(info.buildNumber);
      if (parsedBuild != null) {
        currentBuildNumber.value = parsedBuild;
      }
      _logger?.info(
        'Current application version: ${currentVersion.value}+${currentBuildNumber.value}',
        tag: 'AppUpdateService',
      );
    } catch (e) {
      _logger?.warning(
        'Failed to read PackageInfo; falling back to AppConstants',
        tag: 'AppUpdateService',
        error: e,
      );
    }
  }

  /// Checks for an update.
  /// 1. Tries Firebase Remote Config first (if available and not [forceHttp]).
  /// 2. Falls back to HTTP JSON manifest at [customManifestUrl] or [AppConstants.defaultUpdateManifestUrl].
  /// If [silent] is true, errors do not show user-facing snackbars.
  Future<AppUpdateInfo?> checkForUpdate({
    String? customManifestUrl,
    bool silent = false,
    bool forceHttp = false,
  }) async {
    status.value = AppUpdateStatus.checking;
    errorMessage.value = '';

    if (!forceHttp) {
      try {
        final rcInfo = await _checkViaRemoteConfig();
        if (rcInfo != null) {
          return rcInfo;
        }
        if (status.value == AppUpdateStatus.upToDate) {
          return null;
        }
      } catch (e) {
        _logger?.warning(
          'Firebase Remote Config check error; falling back to HTTP',
          tag: 'AppUpdateService',
          error: e,
        );
      }
    }

    return await _checkViaHttp(customManifestUrl, silent: silent);
  }

  /// Checks Firebase Remote Config for update metadata.
  Future<AppUpdateInfo?> _checkViaRemoteConfig() async {
    if (Firebase.apps.isEmpty) {
      _logger?.info(
        'Firebase is not initialized; skipping Remote Config check.',
        tag: 'AppUpdateService',
      );
      return null;
    }

    try {
      final remoteConfig = _remoteConfig ?? FirebaseRemoteConfig.instance;

      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1),
        ),
      );

      await remoteConfig.setDefaults(<String, dynamic>{
        AppConstants.keyRemoteConfigLatestVersionCode: currentBuildNumber.value,
        AppConstants.keyRemoteConfigLatestVersionName: currentVersion.value,
        AppConstants.keyRemoteConfigMinSupportedVersionCode: 0,
        AppConstants.keyRemoteConfigApkDownloadUrl: '',
        AppConstants.keyRemoteConfigReleaseNotes: '',
        AppConstants.keyRemoteConfigForceUpdate: false,
      });

      final updated = await remoteConfig.fetchAndActivate();
      _logger?.info('Firebase Remote Config fetchAndActivate: $updated', tag: 'AppUpdateService');

      final latestBuildNumber = _getRemoteConfigInt(
        remoteConfig,
        [AppConstants.keyRemoteConfigLatestVersionCode, 'version_code', 'build_number'],
      );
      final apkUrl = _getRemoteConfigString(
        remoteConfig,
        [AppConstants.keyRemoteConfigApkDownloadUrl, 'download_url', 'apk_url'],
      );

      // If Remote Config is unconfigured or empty, return null so HTTP fallback runs
      if (latestBuildNumber <= 0 || apkUrl.isEmpty) {
        _logger?.info(
          'Remote Config does not contain active update parameters (build=$latestBuildNumber, url=$apkUrl); falling back',
          tag: 'AppUpdateService',
        );
        return null;
      }

      final latestVersionName = _getRemoteConfigString(
        remoteConfig,
        [AppConstants.keyRemoteConfigLatestVersionName, 'version_name', 'latest_version', 'version'],
      );
      final minSupportedBuild = _getRemoteConfigInt(
        remoteConfig,
        [AppConstants.keyRemoteConfigMinSupportedVersionCode, 'min_version_code', 'min_supported_build'],
      );
      final rawNotes = _getRemoteConfigString(
        remoteConfig,
        [AppConstants.keyRemoteConfigReleaseNotes, 'release_notes'],
      );
      final forceUpdateConfig = _getRemoteConfigBool(
        remoteConfig,
        [AppConstants.keyRemoteConfigForceUpdate, 'force_update'],
      );

      final isNewer = latestBuildNumber > currentBuildNumber.value;
      if (!isNewer) {
        updateInfo.value = null;
        status.value = AppUpdateStatus.upToDate;
        _logger?.info(
          'App is up to date according to Remote Config (Current: ${currentBuildNumber.value}, Remote: $latestBuildNumber)',
          tag: 'AppUpdateService',
        );
        return null;
      }

      final isForced = forceUpdateConfig || (minSupportedBuild > currentBuildNumber.value);
      final parsedNotes = _parseReleaseNotes(rawNotes);

      final info = AppUpdateInfo(
        latestVersion: latestVersionName.isNotEmpty ? latestVersionName : '$latestBuildNumber',
        buildNumber: latestBuildNumber,
        minSupportedBuild: minSupportedBuild,
        apkUrl: apkUrl,
        releaseNotes: parsedNotes,
        forceUpdate: isForced,
      );

      updateInfo.value = info;
      status.value = AppUpdateStatus.updateAvailable;
      _logger?.info(
        'New update available via Remote Config: v${info.latestVersion} (Build ${info.buildNumber})',
        tag: 'AppUpdateService',
      );
      return info;
    } catch (e) {
      _logger?.warning(
        'Remote Config update check failed; falling back to HTTP',
        tag: 'AppUpdateService',
        error: e,
      );
      return null;
    }
  }

  int _getRemoteConfigInt(FirebaseRemoteConfig rc, List<String> keys) {
    for (final key in keys) {
      try {
        final val = rc.getInt(key);
        if (val > 0) return val;
      } catch (_) {}
      try {
        final strVal = rc.getString(key);
        final parsed = int.tryParse(strVal);
        if (parsed != null && parsed > 0) return parsed;
      } catch (_) {}
    }
    return 0;
  }

  String _getRemoteConfigString(FirebaseRemoteConfig rc, List<String> keys) {
    for (final key in keys) {
      try {
        final val = rc.getString(key).trim();
        if (val.isNotEmpty) return val;
      } catch (_) {}
    }
    return '';
  }

  bool _getRemoteConfigBool(FirebaseRemoteConfig rc, List<String> keys) {
    for (final key in keys) {
      try {
        final val = rc.getBool(key);
        if (val) return true;
      } catch (_) {}
      try {
        final strVal = rc.getString(key).trim().toLowerCase();
        if (strVal == 'true' || strVal == '1') return true;
      } catch (_) {}
    }
    return false;
  }

  List<String> _parseReleaseNotes(String rawNotes) {
    if (rawNotes.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(rawNotes);
      if (decoded is List) {
        return decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
    } catch (_) {}
    return rawNotes
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'^[\s*\-•]+'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  /// Checks for an update against the remote HTTP manifest.
  Future<AppUpdateInfo?> _checkViaHttp(
    String? customManifestUrl, {
    bool silent = false,
  }) async {
    final manifestUrl = customManifestUrl ?? AppConstants.defaultUpdateManifestUrl;
    _logger?.info('Checking for app update at HTTP manifest: $manifestUrl', tag: 'AppUpdateService');

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
      final uri = Uri.parse(manifestUrl);
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'StreamHub/${currentVersion.value} (Android)');
      request.headers.set('Accept', 'application/json');

      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode == 404) {
        _logger?.info(
          'Update manifest returned 404; no newer version published. App is up to date.',
          tag: 'AppUpdateService',
        );
        updateInfo.value = null;
        status.value = AppUpdateStatus.upToDate;
        return null;
      }
      if (response.statusCode != 200) {
        throw HttpException('Server responded with status code ${response.statusCode}');
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final trimmedBody = responseBody.trim();
      if (!trimmedBody.startsWith('{')) {
        throw const FormatException(
          'Update server did not return a valid JSON manifest (received HTML/plain text).',
        );
      }

      final Map<String, dynamic> json = jsonDecode(trimmedBody);
      final info = AppUpdateInfo.fromJson(json);

      final isNewer = info.buildNumber > currentBuildNumber.value;
      if (isNewer) {
        updateInfo.value = info;
        status.value = AppUpdateStatus.updateAvailable;
        _logger?.info(
          'New update available via HTTP manifest: v${info.latestVersion} (Build ${info.buildNumber})',
          tag: 'AppUpdateService',
        );
        return info;
      } else {
        updateInfo.value = null;
        status.value = AppUpdateStatus.upToDate;
        _logger?.info('App is up to date (Build ${currentBuildNumber.value})', tag: 'AppUpdateService');
        return null;
      }
    } catch (e) {
      status.value = AppUpdateStatus.error;
      errorMessage.value = 'Failed to check for updates: $e';
      _logger?.warning('App update check failed', tag: 'AppUpdateService', error: e);
      if (!silent) {
        final String message;
        if (e is SocketException || e is TimeoutException) {
          message = 'Could not reach update server. Please verify your internet connection.';
        } else if (e is FormatException) {
          message = 'The update server did not return a valid JSON manifest.';
        } else {
          message = 'Could not check for updates ($e). Please try again later.';
        }
        Get.snackbar(
          'Update Check Failed',
          message,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5),
        );
      }
      return null;
    } finally {
      client?.close();
    }
  }

  /// Opens the download URL in the external system browser.
  Future<bool> openInBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        _logger?.info('Opened update URL in external browser: $url', tag: 'AppUpdateService');
        return launched;
      } else {
        _logger?.warning('Cannot launch URL in browser: $url', tag: 'AppUpdateService');
      }
    } catch (e) {
      _logger?.error('Failed to open download URL in browser', tag: 'AppUpdateService', error: e);
    }
    return false;
  }

  /// Downloads the APK and triggers system installation.
  /// On Desktop, opens the download URL in the system browser.
  Future<bool> startDownloadAndInstall(AppUpdateInfo info) async {
    if (PlatformHelper.isDesktop) {
      try {
        final uri = Uri.parse(info.apkUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
      } catch (e) {
        _logger?.error('Failed to launch desktop download URL', tag: 'AppUpdateService', error: e);
      }
      return false;
    }

    if (!PlatformHelper.isAndroid) {
      _logger?.warning('In-app self-update is only supported on Android and Desktop', tag: 'AppUpdateService');
      return false;
    }

    _isCancelled = false;
    status.value = AppUpdateStatus.downloading;
    downloadProgress.value = 0.0;
    downloadStatusMessage.value = 'Connecting to download server...';
    errorMessage.value = '';

    HttpClient? client;

    try {
      final tempDir = await getTemporaryDirectory();
      final targetFile = File('${tempDir.path}/streamhub_update_${info.buildNumber}.apk');

      // Delete older partial download if present
      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }

      client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
      final uri = Uri.parse(info.apkUrl);
      final request = await client.getUrl(uri);
      _activeDownloadRequest = request;

      request.headers.set('User-Agent', 'StreamHub/${currentVersion.value} (Android)');

      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('Download failed with status ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      final sink = targetFile.openWrite();
      _activeDownloadSink = sink;

      int receivedBytes = 0;

      await for (final chunk in response) {
        if (_isCancelled) {
          await sink.close();
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          status.value = AppUpdateStatus.idle;
          return false;
        }

        sink.add(chunk);
        receivedBytes += chunk.length;

        if (contentLength > 0) {
          final progress = (receivedBytes / contentLength).clamp(0.0, 1.0);
          downloadProgress.value = progress;
          final receivedMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          final totalMb = (contentLength / (1024 * 1024)).toStringAsFixed(1);
          final pct = (progress * 100).toInt();
          downloadStatusMessage.value = '$receivedMb MB / $totalMb MB ($pct%)';
        } else {
          final receivedMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          downloadStatusMessage.value = '$receivedMb MB downloaded';
        }
      }

      await sink.flush();
      await sink.close();
      _activeDownloadSink = null;

      status.value = AppUpdateStatus.downloaded;
      _logger?.info('APK update downloaded to ${targetFile.path}', tag: 'AppUpdateService');

      return await installApk(targetFile.path);
    } catch (e) {
      if (_isCancelled) {
        status.value = AppUpdateStatus.idle;
        return false;
      }
      status.value = AppUpdateStatus.error;
      errorMessage.value = 'Failed to download update: $e';
      _logger?.error('Failed to download update APK', tag: 'AppUpdateService', error: e);
      return false;
    } finally {
      client?.close();
      _activeDownloadRequest = null;
      _activeDownloadSink = null;
    }
  }

  /// Cancels an in-progress download.
  void cancelDownload() {
    _isCancelled = true;
    try {
      _activeDownloadRequest?.abort();
    } catch (_) {}
    try {
      _activeDownloadSink?.close();
    } catch (_) {}
    status.value = AppUpdateStatus.idle;
    downloadProgress.value = 0.0;
    downloadStatusMessage.value = '';
  }

  /// Invokes the Android system Package Installer for the specified file.
  Future<bool> installApk(String filePath) async {
    if (!PlatformHelper.isAndroid) return false;

    status.value = AppUpdateStatus.installing;
    try {
      final success = await _platformChannel.invokeMethod<bool>(
        'installApk',
        {'filePath': filePath},
      );
      _logger?.info('Invoked native installApk: $success', tag: 'AppUpdateService');
      return success ?? false;
    } on PlatformException catch (e) {
      status.value = AppUpdateStatus.error;
      errorMessage.value = 'Installation error: ${e.message}';
      _logger?.error('Native installApk error', tag: 'AppUpdateService', error: e);
      return false;
    }
  }

  /// Checks if the app has permission to install unknown apps (Android 8.0+).
  Future<bool> canRequestPackageInstalls() async {
    if (!PlatformHelper.isAndroid) return true;
    try {
      final allowed = await _platformChannel.invokeMethod<bool>('canRequestPackageInstalls');
      return allowed ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Directs user to the system Settings page to allow installing unknown apps.
  Future<bool> openInstallPermissionSettings() async {
    if (!PlatformHelper.isAndroid) return false;
    try {
      final opened = await _platformChannel.invokeMethod<bool>('openInstallPermissionSettings');
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }
}
