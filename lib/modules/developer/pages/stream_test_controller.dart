import 'package:get/get.dart';
import 'package:stream_hub/core/iptv/tools/playback_test_tool.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import '../developer_controller.dart';

class StreamTestController extends GetxController {
  final _mediaItemId = ''.obs;
  final _streamUrl = ''.obs;
  final _providerType = MediaSourceType.custom.obs;
  final _providerId = ''.obs;
  final _isRunning = false.obs;
  final _result = Rxn<PlaybackTestResult>();
  final _error = Rxn<String>();
  final LoggingService _logger = LoggingService();

  String get mediaItemId => _mediaItemId.value;
  String get streamUrl => _streamUrl.value;
  MediaSourceType get providerType => _providerType.value;
  String get providerId => _providerId.value;
  bool get isRunning => _isRunning.value;
  PlaybackTestResult? get result => _result.value;
  String? get error => _error.value;

  void updateMediaItemId(String value) => _mediaItemId.value = value;
  void updateStreamUrl(String value) => _streamUrl.value = value;
  void updateProviderId(String value) => _providerId.value = value;

  void setProviderType(MediaSourceType type) => _providerType.value = type;

  List<MediaSourceType> get providerTypes => const [
        MediaSourceType.m3u,
        MediaSourceType.xtream,
        MediaSourceType.stalker,
        MediaSourceType.xmltv,
        MediaSourceType.localPlaylist,
        MediaSourceType.custom,
        MediaSourceType.future,
      ];

  Future<void> run() async {
    final mediaItemId = _mediaItemId.value.trim();
    final streamUrl = _streamUrl.value.trim();
    if (mediaItemId.isEmpty || streamUrl.isEmpty) {
      _error.value = 'Enter a media item ID and stream URL first.';
      return;
    }
    _isRunning.value = true;
    _result.value = null;
    _error.value = null;
    try {
      final core = Get.find<DeveloperController>().core;
      _result.value = await core.streamTestTool.testItem(
        mediaItemId: mediaItemId,
        providerType: _providerType.value,
        itemMetadata: {'streamUrl': streamUrl},
        providerId: _providerId.value.trim().isEmpty
            ? null
            : _providerId.value.trim(),
        validate: true,
      );
    } catch (e, stackTrace) {
      _logger.error('Stream test failed', tag: 'StreamTest', error: e, stackTrace: stackTrace);
      _error.value = e.toString();
    } finally {
      _isRunning.value = false;
    }
  }
}
