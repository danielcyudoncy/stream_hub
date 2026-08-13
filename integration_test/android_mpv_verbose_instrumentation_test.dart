import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;

/// Verbose mpv instrumentation harness.
///
/// Constructs the EXACT same native pipeline the production
/// MediaKitPlayerAdapter uses (mk.Player() default configuration +
/// VideoController), the only difference being the mpv log level raised to
/// 'v'. Dumps every mpv log message and samples mpv core properties to prove
/// per-stage decode/render behavior:
///
///   Network -> Demuxer -> Video packets -> Video decoder -> Decoded frames
///   -> GPU upload -> OpenGL texture -> Flutter texture -> Screen
///
/// No production code is modified.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mpv verbose evidence: decode vs render on device', (
    tester,
  ) async {
    mk.MediaKit.ensureInitialized();

    const streamUrl = String.fromEnvironment(
      'LIVE_STREAM_URL',
      defaultValue: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
    );

    final player = mk.Player(
      configuration: const mk.PlayerConfiguration(logLevel: mk.MPVLogLevel.v),
    );
    final controller = mkv.VideoController(player);
    addTearDown(() async {
      await player.dispose();
    });

    final logLines = <String>[];
    player.stream.log.listen((log) {
      final line = '[${log.prefix}][${log.level}] ${log.text}';
      logLines.add(line);
      debugPrint('MPVLOG $line');
    });

    player.stream.videoParams.listen((p) {
      debugPrint(
        'VIDEOPARAMS pixelformat=${p.pixelformat} '
        'hwPixelformat=${p.hwPixelformat} w=${p.w} h=${p.h} '
        'dw=${p.dw} dh=${p.dh} aspect=${p.aspect} colormatrix=${p.colormatrix}',
      );
    });

    player.stream.audioParams.listen((p) {
      debugPrint(
        'AUDIOPARAMS format=${p.format} channels=${p.channels} '
        'sampleRate=${p.sampleRate}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ColoredBox(
          color: Colors.black,
          child: Center(child: mkv.Video(controller: controller)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    debugPrint('MPV_EVIDENCE opening $streamUrl');
    await player.open(
      mk.Media(streamUrl, httpHeaders: const {'User-Agent': 'StreamHub/1.0'}),
    );
    debugPrint('MPV_EVIDENCE open() resolved');
    await player.play();
    debugPrint('MPV_EVIDENCE play() issued');

    final deadline = DateTime.now().add(const Duration(seconds: 45));
    var lastSample = DateTime.now();
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (DateTime.now().difference(lastSample).inSeconds >= 3) {
        lastSample = DateTime.now();
        await _sample(player);
      }
    }
    await _sample(player);
    await player.pause();
    debugPrint('MPV_EVIDENCE ==== END RUN ====');
  });
}

Future<String?> _prop(mk.Player player, String name) async {
  try {
    final platform = player.platform;
    if (platform == null) return null;
    return await (platform as dynamic).getProperty(name) as String?;
  } catch (_) {
    return null;
  }
}

Future<void> _sample(mk.Player player) async {
  final s = player.state;
  debugPrint(
    'MPV_SAMPLE position=${s.position} duration=${s.duration} '
    'playing=${s.playing} buffering=${s.buffering} '
    'size=${s.width}x${s.height} '
    'vpixel=${s.videoParams.pixelformat} '
    'vhwpixel=${s.videoParams.hwPixelformat} '
    'decoded=${await _prop(player, 'decoded-frame-count')} '
    'dropped=${await _prop(player, 'frame-drop-count')} '
    'video-pts=${await _prop(player, 'video-pts')} '
    'audio-pts=${await _prop(player, 'audio-pts')} '
    'avsync=${await _prop(player, 'avsync')} '
    'playback-time=${await _prop(player, 'playback-time')} '
    'vo=${await _prop(player, 'vo')} '
    'hwdec=${await _prop(player, 'hwdec')} '
    'hwdec-codec=${await _prop(player, 'hwdec-codec')} '
    'vcodec=${await _prop(player, 'video-params/codec')} '
    'container-fps=${await _prop(player, 'container-fps')} '
    'estimated-fps=${await _prop(player, 'estimated-vf-fps')} '
    'gpu-context=${await _prop(player, 'gpu-context')} '
    'gpu-backend=${await _prop(player, 'gpu-backend')} '
    'opengl-es=${await _prop(player, 'opengl-es')}',
  );
}
