import 'package:stream_hub/data/models/xmltv_models.dart';

class TimelineEngine {
  XMLTVGuide? _guide;

  void loadGuide(XMLTVGuide guide) {
    _guide = guide;
  }

  List<XMLTVProgram> current(DateTime time) {
    if (_guide == null) return [];
    return _guide!.programs
        .where((p) => !time.isBefore(p.start) && !time.isAfter(p.end))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  List<XMLTVProgram> next(DateTime time, {int limit = 5}) {
    if (_guide == null) return [];
    final results = _guide!.programs
        .where((p) => p.start.isAfter(time))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    if (results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }

  List<XMLTVProgram> today(DateTime date) {
    if (_guide == null) return [];
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _guide!.programs
        .where((p) => p.start.isBefore(end) && p.end.isAfter(start))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  List<XMLTVProgram> tomorrow(DateTime date) {
    final tomorrow = date.add(const Duration(days: 1));
    return today(tomorrow);
  }

  List<XMLTVProgram> week(DateTime date) {
    if (_guide == null) return [];
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 7));
    return _guide!.programs
        .where((p) => p.start.isBefore(end) && p.end.isAfter(start))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  List<XMLTVProgram> findByTime(DateTime time) {
    if (_guide == null) return [];
    return _guide!.programs
        .where((p) => !time.isBefore(p.start) && !time.isAfter(p.end))
        .toList();
  }

  List<XMLTVProgram> findByChannel(String channelId) {
    if (_guide == null) return [];
    return _guide!.programs
        .where((p) => p.channelId == channelId)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  List<XMLTVProgram> findByChannelAndTime(String channelId, DateTime time) {
    return findByChannel(channelId)
        .where((p) => !time.isBefore(p.start) && !time.isAfter(p.end))
        .toList();
  }

  XMLTVProgram? getCurrentProgram(String channelId, DateTime time) {
    final programs = findByChannel(channelId);
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
    final programs = findByChannel(channelId);
    for (final p in programs) {
      if (p.start.isAfter(time)) {
        return p;
      }
    }
    return null;
  }

  List<XMLTVProgram> getProgramsByChannel(String channelId) {
    return findByChannel(channelId);
  }

  Map<String, List<XMLTVProgram>> getTimelineForAllChannels(DateTime time) {
    if (_guide == null) return {};
    final result = <String, List<XMLTVProgram>>{};
    for (final channel in _guide!.channels) {
      result[channel.id] = findByChannelAndTime(channel.id, time);
    }
    return result;
  }
}