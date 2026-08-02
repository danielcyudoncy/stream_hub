import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:stream_hub/core/bindings/stream_engine_binding.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/streaming/cache/session_cache.dart';
import 'package:stream_hub/core/streaming/controllers/authentication_controller.dart';
import 'package:stream_hub/core/streaming/controllers/playback_session_controller.dart';
import 'package:stream_hub/core/streaming/controllers/session_controller.dart';
import 'package:stream_hub/core/streaming/controllers/stream_health_controller.dart';
import 'package:stream_hub/core/streaming/stream_engine.dart';
import 'package:stream_hub/data/services/provider_session_local_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    tempDir = Directory.systemTemp.createTempSync('stream_engine_binding');
    Hive.init(tempDir.path);
    Get.put<LoggingService>(LoggingService(), permanent: true);
  });

  tearDown(() {
    Get.reset();
    try {
      tempDir.deleteSync(recursive: true);
    } on FileSystemException {
      // Best effort cleanup.
    }
  });

  test('StreamEngineBinding resolves synchronously without hanging', () {
    StreamEngineBinding().dependencies();

    expect(
      Get.isRegistered<ProviderSessionLocalService>(),
      isTrue,
      reason: 'ProviderSessionLocalService must be registered synchronously so '
          'SessionCache can be built during startup (regression: putAsync '
          'never resolves before Get.find).',
    );
    expect(Get.find<ProviderSessionLocalService>(), isA<ProviderSessionLocalService>());
    expect(Get.find<SessionCache>(), isA<SessionCache>());
    expect(Get.find<StreamEngine>(), isA<StreamEngine>());
    expect(Get.isRegistered<SessionController>(), isTrue);
    expect(Get.isRegistered<PlaybackSessionController>(), isTrue);
    expect(Get.isRegistered<StreamHealthController>(), isTrue);
    expect(Get.isRegistered<AuthenticationController>(), isTrue);
  });
}
