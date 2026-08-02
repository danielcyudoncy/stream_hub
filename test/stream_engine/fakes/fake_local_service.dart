import 'package:stream_hub/data/services/provider_session_local_service.dart';

/// In-memory [ProviderSessionLocalService] so session cache tests run without
/// Hive.
class FakeLocalService extends ProviderSessionLocalService {
  final Map<String, ProviderSessionCacheModel> store = {};

  @override
  Future<void> save(ProviderSessionCacheModel model) async {
    store[model.providerId] = model;
  }

  @override
  Future<ProviderSessionCacheModel?> get(String providerId) async {
    return store[providerId];
  }

  @override
  Future<List<ProviderSessionCacheModel>> getAll() async {
    return store.values.toList();
  }

  @override
  Future<void> delete(String providerId) async {
    store.remove(providerId);
  }

  @override
  Future<void> clear() async {
    store.clear();
  }
}
