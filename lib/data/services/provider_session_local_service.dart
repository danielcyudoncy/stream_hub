import 'dart:async';
import 'package:hive/hive.dart';
import 'package:stream_hub/core/logging/logging_service.dart';

/// Persisted representation of a [ProviderSession].
///
/// Sensitive fields (tokens, credentials, cookies) are stored encrypted by the
/// session cache layer; this model only carries opaque blobs.
class ProviderSessionCacheModel extends HiveObject {
  final String providerId;
  final int providerTypeIndex;
  final String sessionId;
  final Map<String, dynamic> data;

  ProviderSessionCacheModel({
    required this.providerId,
    required this.providerTypeIndex,
    required this.sessionId,
    required this.data,
  });
}

class ProviderSessionCacheModelAdapter
    extends TypeAdapter<ProviderSessionCacheModel> {
  @override
  final int typeId = 20;

  @override
  ProviderSessionCacheModel read(BinaryReader reader) {
    return ProviderSessionCacheModel(
      providerId: reader.readString(),
      providerTypeIndex: reader.readInt(),
      sessionId: reader.readString(),
      data: Map<String, dynamic>.from(reader.readMap().cast<String, dynamic>()),
    );
  }

  @override
  void write(BinaryWriter writer, ProviderSessionCacheModel obj) {
    writer.writeString(obj.providerId);
    writer.writeInt(obj.providerTypeIndex);
    writer.writeString(obj.sessionId);
    writer.writeMap(obj.data);
  }
}

/// Hive-backed persistence for provider sessions.
class ProviderSessionLocalService {
  static const String boxName = 'provider_sessions';

  final LoggingService logger;
  Box<ProviderSessionCacheModel>? _box;
  Future<void>? _initFuture;

  ProviderSessionLocalService({LoggingService? logger})
      : logger = logger ?? LoggingService();

  /// Opens the Hive box. Idempotent: safe to call from the binding, from the
  /// splash screen and from every persistence method.
  Future<void> init() => _initFuture ??= _open();

  Future<void> _open() async {
    if (!Hive.isBoxOpen(boxName)) {
      if (!Hive.isAdapterRegistered(20)) {
        Hive.registerAdapter(ProviderSessionCacheModelAdapter());
      }
      _box = await Hive.openBox<ProviderSessionCacheModel>(boxName);
    } else {
      _box = Hive.box<ProviderSessionCacheModel>(boxName);
    }
    logger.info('ProviderSessionLocalService initialized', tag: 'SessionCache');
  }

  Future<void> save(ProviderSessionCacheModel model) async {
    await init();
    await _box?.put(model.providerId, model);
  }

  Future<ProviderSessionCacheModel?> get(String providerId) async {
    await init();
    return _box?.get(providerId);
  }

  Future<List<ProviderSessionCacheModel>> getAll() async {
    await init();
    return _box?.values.toList() ?? [];
  }

  Future<void> delete(String providerId) async {
    await init();
    await _box?.delete(providerId);
  }

  Future<void> clear() async {
    await init();
    await _box?.clear();
  }
}
