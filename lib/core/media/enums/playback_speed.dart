enum PlaybackSpeed {
  speed0_5(0.5, '0.5x'),
  speed0_75(0.75, '0.75x'),
  speed1_0(1.0, '1.0x'),
  speed1_25(1.25, '1.25x'),
  speed1_5(1.5, '1.5x'),
  speed1_75(1.75, '1.75x'),
  speed2_0(2.0, '2.0x');

  final double value;
  final String label;

  const PlaybackSpeed(this.value, this.label);

  static PlaybackSpeed fromValue(double value) {
    return PlaybackSpeed.values.firstWhere(
      (s) => s.value == value,
      orElse: () => PlaybackSpeed.speed1_0,
    );
  }
}
