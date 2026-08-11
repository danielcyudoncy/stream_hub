import 'package:get/get.dart';
import 'package:stream_hub/core/errors/exceptions.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/account_metadata_provider.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/media_source_factory.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/media_source_repository.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_enums.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_model.dart';

class ProviderSyncResult {
  final ProviderModel provider;
  final bool success;
  final String? message;

  const ProviderSyncResult({
    required this.provider,
    required this.success,
    this.message,
  });
}

/// Owns the full sync flow for a provider: creates and registers the media
/// source, pulls the catalog, and persists the resulting status on the
/// [ProviderModel]. Controllers and startup flows both delegate here so sync
/// behavior stays in one place.
class ProviderSyncService extends GetxService {
  final ProviderRepository _repository;
  final MediaSourceFactory _sourceFactory;
  final MediaSourceRepository _sourceRepo;
  final CatalogRepository _catalogRepo;
  final LoggingService _logger;

  ProviderSyncService({
    required ProviderRepository repository,
    required MediaSourceFactory sourceFactory,
    required MediaSourceRepository sourceRepo,
    required CatalogRepository catalogRepo,
    required LoggingService logger,
  }) : _repository = repository,
       _sourceFactory = sourceFactory,
       _sourceRepo = sourceRepo,
       _catalogRepo = catalogRepo,
       _logger = logger;

  /// Syncs every enabled provider. Providers are synced sequentially so
  /// concurrent servers are never hammered at once.
  Future<List<ProviderSyncResult>> syncAll() async {
    final List<ProviderModel> providers;
    try {
      providers = await _repository.getAllProviders();
    } catch (e) {
      _logger.warning(
        'Failed to load providers for startup sync',
        tag: 'ProviderSyncService',
        error: e,
      );
      return const [];
    }

    final results = <ProviderSyncResult>[];
    for (final provider in providers.where((p) => p.enabled)) {
      results.add(await syncProvider(provider));
    }
    return results;
  }

  Future<ProviderSyncResult> syncProvider(ProviderModel provider) async {
    final sourceType = _toMediaSourceType(provider.providerType);
    if (sourceType == null) {
      return ProviderSyncResult(
        provider: provider,
        success: false,
        message: 'Unsupported provider type "${provider.providerType.displayName}".',
      );
    }

    try {
      final source = _sourceFactory.create(
        provider.id,
        sourceType,
        _buildConfig(provider, sourceType),
      );
      await _sourceRepo.register(source);
      final result = await _catalogRepo.syncSource(provider.id);

      if (result.success) {
        final account = source is AccountMetadataProvider
            ? (source as AccountMetadataProvider).accountMetadata
            : null;
        await _repository.updateProvider(
          provider.copyWith(
            status: ProviderStatus.active,
            lastSync: DateTime.now(),
            accountCreatedAt: account?.createdAt,
            accountExpiresAt: account?.expiresAt,
            accountStatus: account?.status,
            accountIsTrial: account?.isTrial,
            accountMaxConnections: account?.maxConnections,
          ),
        );
        return ProviderSyncResult(provider: provider, success: true);
      } else {
        await _repository.updateProvider(
          provider.copyWith(status: ProviderStatus.error),
        );
        return ProviderSyncResult(
          provider: provider,
          success: false,
          message: _friendlySyncMessage(result.error, provider),
        );
      }
    } catch (e) {
      _logger.warning('Provider sync failed', tag: 'ProviderSyncService', error: e);
      final message = _friendlySyncMessage(
        e is ApplicationException ? e.message : null,
        provider,
      );
      try {
        await _repository.updateProvider(
          provider.copyWith(status: ProviderStatus.error),
        );
      } catch (_) {}
      return ProviderSyncResult(provider: provider, success: false, message: message);
    }
  }

  Map<String, dynamic> _buildConfig(ProviderModel provider, MediaSourceType sourceType) {
    final config = <String, dynamic>{
      'sourceUrl': provider.serverUrl ?? '',
    };
    if (provider.username != null) config['username'] = provider.username;
    if (provider.password != null) config['password'] = provider.password;
    if (sourceType == MediaSourceType.stalker) {
      config['portalUrl'] = provider.serverUrl ?? '';
      if (provider.macAddress != null) {
        config['macAddress'] = provider.macAddress;
      }
    }
    return config;
  }

  MediaSourceType? _toMediaSourceType(ProviderType type) {
    switch (type) {
      case ProviderType.m3u:
        return MediaSourceType.m3u;
      case ProviderType.xtream:
        return MediaSourceType.xtream;
      case ProviderType.stalker:
        return MediaSourceType.stalker;
      case ProviderType.xmltv:
        return MediaSourceType.xmltv;
      case ProviderType.custom:
        return MediaSourceType.custom;
    }
  }

  String _friendlySyncMessage(String? raw, ProviderModel provider) {
    if (raw == null || raw.isEmpty) {
      return 'Could not connect to "${provider.name}". Check that the server is online and your credentials are correct.';
    }
    if (raw.contains('SocketException') || raw.contains('Failed host lookup')) {
      return 'Could not reach "${provider.name}" server. Check that the server URL is correct and you are online.';
    }
    if (raw.contains('TimeoutException') || raw.toLowerCase().contains('timed out')) {
      return 'Connection to "${provider.name}" timed out. Please try again.';
    }
    return raw;
  }
}
