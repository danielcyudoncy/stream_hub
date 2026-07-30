import 'package:stream_hub/modules/epg/models/epg_program.dart';

class EPGTimelineEntry {
  final EPGProgram program;
  final DateTime slotStart;
  final DateTime slotEnd;
  final bool isCurrent;
  final bool isPast;
  final bool isFuture;

  const EPGTimelineEntry({
    required this.program,
    required this.slotStart,
    required this.slotEnd,
    this.isCurrent = false,
    this.isPast = false,
    this.isFuture = false,
  });

  EPGTimelineEntry copyWith({
    EPGProgram? program,
    DateTime? slotStart,
    DateTime? slotEnd,
    bool? isCurrent,
    bool? isPast,
    bool? isFuture,
  }) {
    return EPGTimelineEntry(
      program: program ?? this.program,
      slotStart: slotStart ?? this.slotStart,
      slotEnd: slotEnd ?? this.slotEnd,
      isCurrent: isCurrent ?? this.isCurrent,
      isPast: isPast ?? this.isPast,
      isFuture: isFuture ?? this.isFuture,
    );
  }

  double get progressPercent {
    if (isPast || isFuture) return 0.0;
    final now = DateTime.now();
    if (now.isBefore(slotStart) || now.isAfter(slotEnd)) return 0.0;
    final totalDuration = slotEnd.difference(slotStart).inMilliseconds;
    if (totalDuration <= 0) return 0.0;
    final elapsed = now.difference(slotStart).inMilliseconds;
    return (elapsed / totalDuration).clamp(0.0, 1.0);
  }

  Duration get remainingTime {
    if (isPast) return Duration.zero;
    final now = DateTime.now();
    if (now.isAfter(slotEnd)) return Duration.zero;
    return slotEnd.difference(now);
  }
}