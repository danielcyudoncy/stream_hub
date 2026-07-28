import 'package:stream_hub/core/media/enums/media_source_type.dart';

class MediaSourceConnectedEvent {
  final String sourceId;
  final MediaSourceType type;
  final DateTime occurredAt;

  const MediaSourceConnectedEvent({
    required this.sourceId,
    required this.type,
    required this.occurredAt,
  });
}

class MediaSourceRemovedEvent {
  final String sourceId;
  final MediaSourceType type;
  final DateTime occurredAt;

  const MediaSourceRemovedEvent({
    required this.sourceId,
    required this.type,
    required this.occurredAt,
  });
}

class CatalogUpdatedEvent {
  final String sourceId;
  final int addedItems;
  final int updatedItems;
  final int removedItems;
  final DateTime occurredAt;

  const CatalogUpdatedEvent({
    required this.sourceId,
    this.addedItems = 0,
    this.updatedItems = 0,
    this.removedItems = 0,
    required this.occurredAt,
  });
}

class SearchCompletedEvent {
  final String query;
  final int resultCount;
  final Duration duration;
  final DateTime occurredAt;

  const SearchCompletedEvent({
    required this.query,
    required this.resultCount,
    required this.duration,
    required this.occurredAt,
  });
}

class SyncStartedEvent {
  final String sourceId;
  final DateTime occurredAt;

  const SyncStartedEvent({
    required this.sourceId,
    required this.occurredAt,
  });
}

class SyncFinishedEvent {
  final String sourceId;
  final bool success;
  final String? error;
  final DateTime occurredAt;

  const SyncFinishedEvent({
    required this.sourceId,
    required this.success,
    this.error,
    required this.occurredAt,
  });
}

class PlayerRequestedEvent {
  final String itemId;
  final String sourceId;
  final DateTime occurredAt;

  const PlayerRequestedEvent({
    required this.itemId,
    required this.sourceId,
    required this.occurredAt,
  });
}

class MetadataUpdatedEvent {
  final String itemId;
  final DateTime occurredAt;

  const MetadataUpdatedEvent({
    required this.itemId,
    required this.occurredAt,
  });
}
