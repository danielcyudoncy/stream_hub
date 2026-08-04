import 'package:get/get.dart';
import 'package:stream_hub/core/iptv/tools/playback_test_tool.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import '../developer_controller.dart';

class PlaybackTestController extends GetxController {
  final _url = ''.obs;
  final _isRunning = false.obs;
  final _result = Rxn<PlaybackTestResult>();
  final _error = Rxn<String>();
  final LoggingService _logger = LoggingService();

  String get url => _url.value;
  bool get isRunning => _isRunning.value;
  PlaybackTestResult? get result => _result.value;
  String? get error => _error.value;

  void updateUrl(String value) => _url.value = value;

  Future<void> run() async {
    final url = _url.value.trim();
    if (url.isEmpty) {
      _error.value = 'Enter a stream URL first.';
      return;
    }
    _isRunning.value = true;
    _result.value = null;
    _error.value = null;
    try {
      final core = Get.find<DeveloperController>().core;
      _result.value = await core.playbackTestTool.testUrl(url);
    } catch (e, stackTrace) {
      _logger.error('Playback test failed', tag: 'PlaybackTest', error: e, stackTrace: stackTrace);
      _error.value = e.toString();
    } finally {
      _isRunning.value = false;
    }
  }
}
