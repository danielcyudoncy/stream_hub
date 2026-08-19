import 'dart:async';
import 'package:hive/hive.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/playback_analytics_model.dart';
import 'package:stream_hub/data/models/playback_session_model.dart';
import 'package:stream_hub/data/models/player_settings_model.dart';

class PlaybackSessionModelAdapter extends TypeAdapter<PlaybackSessionModel> {
  @override
  final int typeId = 10;

  @override
  PlaybackSessionModel read(BinaryReader reader) {
    return PlaybackSessionModel(
      id: reader.readString(),
      itemId: reader.readString(),
      providerType: reader.readString(),
      resumePosition: Duration(milliseconds: reader.readInt()),
      completionPercentage: reader.readDouble(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, PlaybackSessionModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.itemId);
    writer.writeString(obj.providerType);
    writer.writeInt(obj.resumePosition.inMilliseconds);
    writer.writeDouble(obj.completionPercentage);
    writer.writeInt(obj.updatedAt.millisecondsSinceEpoch);
  }
}

class PlaybackAnalyticsModelAdapter extends TypeAdapter<PlaybackAnalyticsModel> {
  @override
  final int typeId = 11;

  @override
  PlaybackAnalyticsModel read(BinaryReader reader) {
    return PlaybackAnalyticsModel(
      sessionId: reader.readString(),
      itemId: reader.readString(),
      providerType: reader.readString(),
      startedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      endedAt: reader.readInt() > 0
          ? DateTime.fromMillisecondsSinceEpoch(reader.readInt())
          : null,
      totalWatchTimeSeconds: reader.readInt(),
      bufferedTimeSeconds: reader.readInt(),
      channelChanges: reader.readInt(),
      seekCount: reader.readInt(),
      pauseCount: reader.readInt(),
      errorCount: reader.readInt(),
      completionPercentage: reader.readDouble(),
      lastError: reader.readString(),
      startupTimeMs: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, PlaybackAnalyticsModel obj) {
    writer.writeString(obj.sessionId);
    writer.writeString(obj.itemId);
    writer.writeString(obj.providerType);
    writer.writeInt(obj.startedAt.millisecondsSinceEpoch);
    writer.writeInt(obj.endedAt?.millisecondsSinceEpoch ?? 0);
    writer.writeInt(obj.totalWatchTimeSeconds);
    writer.writeInt(obj.bufferedTimeSeconds);
    writer.writeInt(obj.channelChanges);
    writer.writeInt(obj.seekCount);
    writer.writeInt(obj.pauseCount);
    writer.writeInt(obj.errorCount);
    writer.writeDouble(obj.completionPercentage);
    writer.writeString(obj.lastError ?? '');
    writer.writeInt(obj.startupTimeMs);
  }
}

class PlayerSettingsModelAdapter extends TypeAdapter<PlayerSettingsModel> {
  @override
  final int typeId = 12;

  @override
  PlayerSettingsModel read(BinaryReader reader) {
    return PlayerSettingsModel(
      id: reader.readString(),
      defaultQuality: reader.readString(),
      preferredAudioLanguage: reader.readString(),
      preferredSubtitleLanguage: reader.readString(),
      hardwareDecode: reader.readBool(),
      bufferSizeSeconds: reader.readInt(),
      autoResume: reader.readBool(),
      autoFullscreen: reader.readBool(),
      defaultSpeed: reader.readDouble(),
      defaultAspectRatio: reader.readString(),
      rememberPosition: reader.readBool(),
      skipForwardSeconds: reader.readInt(),
      skipBackwardSeconds: reader.readInt(),
      enableSubtitlesByDefault: reader.readBool(),
      enableGestures: reader.readBool(),
      enableKeyboardShortcuts: reader.readBool(),
      enableTvRemote: reader.readBool(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, PlayerSettingsModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.defaultQuality);
    writer.writeString(obj.preferredAudioLanguage);
    writer.writeString(obj.preferredSubtitleLanguage);
    writer.writeBool(obj.hardwareDecode);
    writer.writeInt(obj.bufferSizeSeconds);
    writer.writeBool(obj.autoResume);
    writer.writeBool(obj.autoFullscreen);
    writer.writeDouble(obj.defaultSpeed);
    writer.writeString(obj.defaultAspectRatio);
    writer.writeBool(obj.rememberPosition);
    writer.writeInt(obj.skipForwardSeconds);
    writer.writeInt(obj.skipBackwardSeconds);
    writer.writeBool(obj.enableSubtitlesByDefault);
    writer.writeBool(obj.enableGestures);
    writer.writeBool(obj.enableKeyboardShortcuts);
    writer.writeBool(obj.enableTvRemote);
    writer.writeInt(obj.updatedAt.millisecondsSinceEpoch);
  }
}

class PlaybackLocalService {
  static const String boxSessions = 'playback_sessions';
  static const String boxAnalytics = 'playback_analytics';
  static const String boxSettings = 'player_settings';

  final LoggingService logger;
  Box<PlaybackSessionModel>? _sessionsBox;
  Box<PlaybackAnalyticsModel>? _analyticsBox;
  Box<PlayerSettingsModel>? _settingsBox;

  PlaybackLocalService({LoggingService? logger})
      : logger = logger ?? LoggingService();

  /// Opens the Hive boxes backing sessions, analytics, and player settings.
  ///
  /// Safe to call more than once: boxes are only opened when not already open,
  /// so the type adapters are never registered twice.
  Future<PlaybackLocalService> init() async {
    if (!Hive.isBoxOpen(boxSessions)) {
      Hive.registerAdapter(PlaybackSessionModelAdapter());
      _sessionsBox = await Hive.openBox<PlaybackSessionModel>(boxSessions);
    }
    if (!Hive.isBoxOpen(boxAnalytics)) {
      Hive.registerAdapter(PlaybackAnalyticsModelAdapter());
      _analyticsBox = await Hive.openBox<PlaybackAnalyticsModel>(boxAnalytics);
    }
    if (!Hive.isBoxOpen(boxSettings)) {
      Hive.registerAdapter(PlayerSettingsModelAdapter());
      _settingsBox = await Hive.openBox<PlayerSettingsModel>(boxSettings);
    }
    logger.info('PlaybackLocalService initialized', tag: 'PlaybackLocalService');
    return this;
  }

  Future<void> saveSession(PlaybackSessionModel model) async {
    await _sessionsBox?.put(model.id, model);
  }

  Future<PlaybackSessionModel?> getSession(String id) async {
    return _sessionsBox?.get(id);
  }

  Future<List<PlaybackSessionModel>> getAllSessions() async {
    final list = _sessionsBox?.values.toList() ?? [];
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<void> deleteSession(String id) async {
    await _sessionsBox?.delete(id);
  }

  Future<void> clearSessions() async {
    await _sessionsBox?.clear();
  }

  Future<void> saveAnalytics(PlaybackAnalyticsModel model) async {
    await _analyticsBox?.put(model.sessionId, model);
  }

  Future<List<PlaybackAnalyticsModel>> getAnalytics({int limit = 100}) async {
    final all = _analyticsBox?.values.toList() ?? [];
    all.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return all.take(limit).toList();
  }

  Future<void> saveSettings(PlayerSettingsModel model) async {
    await _settingsBox?.put('player_settings', model);
  }

  Future<PlayerSettingsModel?> getSettings() async {
    return _settingsBox?.get('player_settings');
  }

  Future<void> clearAll() async {
    await _sessionsBox?.clear();
    await _analyticsBox?.clear();
    await _settingsBox?.clear();
  }
}
