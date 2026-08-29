class DateFormatter {
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  static String formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String formatTimeRange(DateTime start, DateTime end, {bool use12Hour = true}) {
    var cleanEnd = end;
    if (cleanEnd.isBefore(start) || cleanEnd == start || cleanEnd.difference(start).inMinutes < 10) {
      cleanEnd = start.add(const Duration(hours: 1));
    }
    if (use12Hour) {
      final hour1 = start.hour == 0 ? 12 : (start.hour > 12 ? start.hour - 12 : start.hour);
      final min1 = start.minute.toString().padLeft(2, '0');
      final amPm1 = start.hour >= 12 ? 'PM' : 'AM';

      final hour2 = cleanEnd.hour == 0 ? 12 : (cleanEnd.hour > 12 ? cleanEnd.hour - 12 : cleanEnd.hour);
      final min2 = cleanEnd.minute.toString().padLeft(2, '0');
      final amPm2 = cleanEnd.hour >= 12 ? 'PM' : 'AM';

      return '$hour1:$min1 $amPm1 - $hour2:$min2 $amPm2';
    } else {
      final hour1 = start.hour.toString().padLeft(2, '0');
      final min1 = start.minute.toString().padLeft(2, '0');
      final hour2 = cleanEnd.hour.toString().padLeft(2, '0');
      final min2 = cleanEnd.minute.toString().padLeft(2, '0');
      return '$hour1:$min1 - $hour2:$min2';
    }
  }

  static String formatDate(DateTime dateTime) {
    final year = dateTime.year;
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String formatRelativeDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    final difference = target.difference(today).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == -1) {
      return 'Yesterday';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else {
      return formatDate(dateTime);
    }
  }
}
