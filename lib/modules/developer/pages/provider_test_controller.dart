import 'package:get/get.dart';
import 'package:stream_hub/core/iptv/tools/provider_test_tool.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import '../developer_controller.dart';

class ProviderTestController extends GetxController {
  final _url = ''.obs;
  final _content = ''.obs;
  final _isRunning = false.obs;
  final _result = Rxn<ProviderTestResult>();
  final _error = Rxn<String>();
  final LoggingService _logger = LoggingService();

  String get url => _url.value;
  String get content => _content.value;
  bool get isRunning => _isRunning.value;
  ProviderTestResult? get result => _result.value;
  String? get error => _error.value;

  void updateUrl(String value) => _url.value = value;
  void updateContent(String value) => _content.value = value;

  Future<void> run() async {
    final url = _url.value.trim();
    final content = _content.value.trim();
    if (url.isEmpty && content.isEmpty) {
      _error.value = 'Enter a provider URL or playlist content first.';
      return;
    }
    _isRunning.value = true;
    _result.value = null;
    _error.value = null;
    try {
      final core = Get.find<DeveloperController>().core;
      _result.value = await core.providerTestTool.analyze(
        url: url.isEmpty ? null : url,
        content: content.isEmpty ? null : content,
      );
    } catch (e, stackTrace) {
      _logger.error('Provider test failed', tag: 'ProviderTest', error: e, stackTrace: stackTrace);
      _error.value = e.toString();
    } finally {
      _isRunning.value = false;
    }
  }
}
