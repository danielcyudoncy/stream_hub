enum PlayerQuality {
  auto,
  p2160,
  p1080,
  p720,
  p480,
  p360,
  audioOnly;

  String get displayName {
    switch (this) {
      case PlayerQuality.auto:
        return 'Auto';
      case PlayerQuality.p2160:
        return '4K';
      case PlayerQuality.p1080:
        return '1080p';
      case PlayerQuality.p720:
        return '720p';
      case PlayerQuality.p480:
        return '480p';
      case PlayerQuality.p360:
        return '360p';
      case PlayerQuality.audioOnly:
        return 'Audio Only';
    }
  }

  String? get resolutionLabel {
    switch (this) {
      case PlayerQuality.p2160:
        return '2160p';
      case PlayerQuality.p1080:
        return '1080p';
      case PlayerQuality.p720:
        return '720p';
      case PlayerQuality.p480:
        return '480p';
      case PlayerQuality.p360:
        return '360p';
      default:
        return null;
    }
  }
}
