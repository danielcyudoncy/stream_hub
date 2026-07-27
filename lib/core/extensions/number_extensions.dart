import 'dart:math';

extension NumberExtensions on num {
  String toFileSize() {
    if (this <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(this) / log(1024)).floor();
    final size = this / pow(1024, i);
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String toFormattedDuration() {
    final duration = Duration(seconds: toInt());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
