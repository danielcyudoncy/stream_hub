import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  AppUpdateService({LoggingService? logger})
      : _logger = logger ?? (Get.isRegistered<LoggingService>() ? Get.find<LoggingService>() : null);

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

  /// Checks for an update against the remote manifest.
  /// If [silent] is true, errors do not show user-facing snackbars.
  Future<AppUpdateInfo?> checkForUpdate({
    String? customManifestUrl,
    bool silent = false,
  }) async {
    final manifestUrl = customManifestUrl ?? AppConstants.defaultUpdateManifestUrl;
    status.value = AppUpdateStatus.checking;
    errorMessage.value = '';

    _logger?.info('Checking for app update at $manifestUrl', tag: 'AppUpdateService');

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
      final uri = Uri.parse(manifestUrl);
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'StreamHub/${currentVersion.value} (Android)');
      request.headers.set('Accept', 'application/json');

      final response = await request.close().timeout(const Duration(seconds: 15));
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
          'New update available: v${info.latestVersion} (Build ${info.buildNumber})',
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
        final message = e is FormatException
            ? 'The update server did not return a valid JSON manifest (received HTML instead).'
            : 'Could not check for updates. Please verify your internet connection.';
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
