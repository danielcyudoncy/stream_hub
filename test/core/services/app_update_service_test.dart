import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/services/app_update_service.dart';
import 'package:stream_hub/data/models/app_update_info.dart';

void main() {
  group('AppUpdateInfo', () {
    test('parses from standard JSON with list of release notes', () {
      final json = {
        'latest_version': '1.2.0',
        'build_number': 5,
        'min_supported_build': 2,
        'apk_url': 'https://streamhub.pro/downloads/streamhub-1.2.0.apk',
        'release_notes': [
          'Performance improvements',
          'Fixed Live TV crash on Mali devices',
        ],
        'force_update': true,
        'file_size': 42100000,
        'sha256': 'abcdef1234567890',
      };

      final info = AppUpdateInfo.fromJson(json);

      expect(info.latestVersion, '1.2.0');
      expect(info.buildNumber, 5);
      expect(info.minSupportedBuild, 2);
      expect(info.apkUrl, 'https://streamhub.pro/downloads/streamhub-1.2.0.apk');
      expect(info.releaseNotes.length, 2);
      expect(info.releaseNotes.first, 'Performance improvements');
      expect(info.forceUpdate, isTrue);
      expect(info.fileSize, 42100000);
      expect(info.sha256, 'abcdef1234567890');
    });

    test('parses multiline release notes string into bullet list', () {
      final json = {
        'version': '1.1.0',
        'version_code': '3',
        'download_url': 'https://example.com/app.apk',
        'release_notes': '• Feature 1\n• Feature 2\n- Feature 3',
        'force_update': false,
      };

      final info = AppUpdateInfo.fromJson(json);

      expect(info.latestVersion, '1.1.0');
      expect(info.buildNumber, 3);
      expect(info.apkUrl, 'https://example.com/app.apk');
      expect(info.releaseNotes, ['Feature 1', 'Feature 2', 'Feature 3']);
      expect(info.forceUpdate, isFalse);
    });

    test('serializes back to JSON correctly', () {
      const info = AppUpdateInfo(
        latestVersion: '2.0.0',
        buildNumber: 10,
        minSupportedBuild: 8,
        apkUrl: 'https://streamhub.pro/v2.apk',
        releaseNotes: ['Major update'],
        forceUpdate: true,
      );

      final json = info.toJson();

      expect(json['latest_version'], '2.0.0');
      expect(json['build_number'], 10);
      expect(json['min_supported_build'], 8);
      expect(json['apk_url'], 'https://streamhub.pro/v2.apk');
      expect(json['release_notes'], ['Major update']);
      expect(json['force_update'], isTrue);
    });
  });

  group('AppUpdateService state', () {
    test('initializes with default idle state and constants fallback', () {
      final service = AppUpdateService();

      expect(service.status.value, AppUpdateStatus.idle);
      expect(service.downloadProgress.value, 0.0);
      expect(service.errorMessage.value, isEmpty);
      expect(service.currentVersion.value, isNotEmpty);
      expect(service.currentBuildNumber.value, greaterThan(0));
    });

    test('cancelDownload resets download progress and status to idle', () {
      final service = AppUpdateService();
      service.status.value = AppUpdateStatus.downloading;
      service.downloadProgress.value = 0.5;
      service.downloadStatusMessage.value = 'Downloading...';

      service.cancelDownload();

      expect(service.status.value, AppUpdateStatus.idle);
      expect(service.downloadProgress.value, 0.0);
      expect(service.downloadStatusMessage.value, isEmpty);
    });
  });
}
