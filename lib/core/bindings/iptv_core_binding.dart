import 'package:get/get.dart';
import 'package:stream_hub/core/iptv/debug/debug_mode_service.dart';
import 'package:stream_hub/core/iptv/iptv_core.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/streaming/stream_engine.dart';
import 'package:stream_hub/core/streaming/validation/stream_validator.dart';

/// Wires the IPTV Core dependency graph using GetX.
///
/// Depends on the [StreamEngine] and [StreamValidator] registered by
/// `StreamEngineBinding`. Registers the facade plus every subsystem so
/// controllers and test tools can resolve them individually.
class IptvCoreBinding extends Bindings {
  @override
  void dependencies() {
    if (Get.isRegistered<IptvCore>()) return;

    final streamEngine = Get.find<StreamEngine>();
    final streamValidator = Get.find<StreamValidator>();
    final logger = Get.find<LoggingService>();

    if (!Get.isRegistered<DebugModeService>()) {
      Get.put<DebugModeService>(
        DebugModeService(logger: logger),
        permanent: true,
      );
    }

    final core = IptvCore(
      streamEngine: streamEngine,
      streamValidator: streamValidator,
      logger: logger,
      debugMode: Get.find<DebugModeService>(),
    );

    Get.put<IptvCore>(core, permanent: true);
  }
}
