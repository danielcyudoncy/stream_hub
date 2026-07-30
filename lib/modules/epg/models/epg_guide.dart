import 'package:stream_hub/modules/epg/models/epg_channel.dart';
import 'package:stream_hub/modules/epg/models/epg_program.dart';

class EPGGuide {
  final String sourceId;
  final List<EPGChannel> channels;
  final List<EPGProgram> programs;
  final DateTime generatedAt;
  final String? version;
  final int? sizeBytes;
  final String? encoding;

  const EPGGuide({
    required this.sourceId,
    this.channels = const [],
    this.programs = const [],
    required this.generatedAt,
    this.version,
    this.sizeBytes,
    this.encoding,
  });

  EPGGuide copyWith({
    String? sourceId,
    List<EPGChannel>? channels,
    List<EPGProgram>? programs,
    DateTime? generatedAt,
    String? version,
    int? sizeBytes,
    String? encoding,
  }) {
    return EPGGuide(
      sourceId: sourceId ?? this.sourceId,
      channels: channels ?? this.channels,
      programs: programs ?? this.programs,
      generatedAt: generatedAt ?? this.generatedAt,
      version: version ?? this.version,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      encoding: encoding ?? this.encoding,
    );
  }

  int get programCount => programs.length;
  int get channelCount => channels.length;
  Set<String> get categories => programs.expand((p) => p.categories ?? <String>[]).toSet();
  Set<String> get languages => programs.where((p) => p.language != null).map((p) => p.language!).toSet();
  Set<String> get countries => programs.where((p) => p.country != null).map((p) => p.country!).toSet();
  Set<String> get genres => programs.expand((p) => p.genres).toSet();
}