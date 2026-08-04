import 'package:get/get.dart';
import 'package:stream_hub/core/iptv/debug/debug_mode_service.dart';
import 'package:stream_hub/core/iptv/iptv_core.dart';

class DeveloperController extends GetxController {
  final IptvCore core;

  DeveloperController(this.core);

  DebugModeService get debugMode => core.debugMode;

  bool get isDebugEnabled => debugMode.isEnabled;
}
