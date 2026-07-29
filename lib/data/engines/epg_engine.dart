import 'package:stream_hub/data/models/xmltv_models.dart';

class EPGEngine {
  final Map<String, XMLTVProgram> _programs = {};
  final Map<String, List<XMLTVProgram>> _programsByChannel = {};
  final Map<String, XMLTVChannel> _channels = {};
  XMLTVGuide? _currentGuide;

  void storeGuide(XMLTVGuide guide) {
    _currentGuide = guide;

    for (final channel in guide.channels) {
      _channels[channel.id] = channel;
    }

    for (final program in guide.programs) {
      _programs[program.id] = program;
      _programsByChannel.putIfAbsent(program.channelId, () => []).add(program);
    }
  }

  void loadGuide(XMLTVGuide guide) {
    storeGuide(guide);
  }

  List<XMLTVProgram> getProgramsByChannel(String channelId) {
    return _programsByChannel[channelId] ?? [];
  }

  XMLTVProgram? getProgramById(String programId) {
    return _programs[programId];
  }

  List<XMLTVProgram> getProgramsByTimeRange(DateTime start, DateTime end) {
    return _programs.values
        .where((p) => p.start.isBefore(end) && p.end.isAfter(start))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  XMLTVProgram? getCurrentProgram(String channelId, DateTime time) {
    final programs = _programsByChannel[channelId] ?? [];
    for (final p in programs) {
      if (!time.isBefore(p.start) && !time.isAfter(p.end)) {
        return p;
      }
    }
    for (final p in programs) {
      if (p.start.isAfter(time)) {
        return p;
      }
    }
    if (programs.isNotEmpty) return programs.last;
    return null;
  }

  XMLTVProgram? getNextProgram(String channelId, DateTime time) {
    final programs = _programsByChannel[channelId] ?? [];
    for (final p in programs) {
      if (p.start.isAfter(time)) {
        return p;
      }
    }
    return null;
  }

  List<XMLTVProgram> getTodayPrograms(String channelId, DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return getProgramsByTimeRange(start, end);
  }

  List<XMLTVProgram> getTomorrowPrograms(String channelId, DateTime date) {
    final tomorrow = date.add(const Duration(days: 1));
    return getTodayPrograms(channelId, tomorrow);
  }

  List<XMLTVProgram> getWeekPrograms(String channelId, DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 7));
    return getProgramsByTimeRange(start, end);
  }

  List<XMLTVProgram> findByTime(DateTime time) {
    return _programs.values
        .where((p) => !time.isBefore(p.start) && !time.isAfter(p.end))
        .toList();
  }

  List<XMLTVProgram> findByChannel(String channelId) {
    return _programsByChannel[channelId] ?? [];
  }

  List<XMLTVProgram> searchPrograms(String query) {
    final lower = query.toLowerCase();
    return _programs.values
        .where((p) =>
            p.title.toLowerCase().contains(lower) ||
            (p.description != null && p.description!.toLowerCase().contains(lower)) ||
            (p.subtitle != null && p.subtitle!.toLowerCase().contains(lower)))
        .toList();
  }

  List<XMLTVChannel> getChannels() {
    return _channels.values.toList();
  }

  XMLTVChannel? getChannel(String channelId) {
    return _channels[channelId];
  }

  int get totalProgramCount => _programs.length;
  int get totalChannelCount => _channels.length;

  XMLTVGuide? get currentGuide => _currentGuide;

  void clear() {
    _programs.clear();
    _programsByChannel.clear();
    _channels.clear();
    _currentGuide = null;
  }
}