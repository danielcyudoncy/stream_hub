import 'package:stream_hub/data/models/metadata_models.dart';

class MetadataUpdatedEvent {
  final String itemId;
  final Set<MetadataSourceType> sources;
  final DateTime occurredAt;

  const MetadataUpdatedEvent({
    required this.itemId,
    this.sources = const {},
    required this.occurredAt,
  });
}

class ArtworkUpdatedEvent {
  final String itemId;
  final String? poster;
  final String? backdrop;
  final String? thumbnail;
  final DateTime occurredAt;

  const ArtworkUpdatedEvent({
    required this.itemId,
    this.poster,
    this.backdrop,
    this.thumbnail,
    required this.occurredAt,
  });
}

class SearchIndexedEvent {
  final int itemCount;
  final DateTime occurredAt;

  const SearchIndexedEvent({
    required this.itemCount,
    required this.occurredAt,
  });
}

class LibraryUpdatedEvent {
  final int totalItems;
  final int liveTVCount;
  final int moviesCount;
  final int seriesCount;
  final DateTime occurredAt;

  const LibraryUpdatedEvent({
    required this.totalItems,
    required this.liveTVCount,
    required this.moviesCount,
    required this.seriesCount,
    required this.occurredAt,
  });
}

class CollectionUpdatedEvent {
  final String collectionType;
  final int itemCount;
  final DateTime occurredAt;

  const CollectionUpdatedEvent({
    required this.collectionType,
    required this.itemCount,
    required this.occurredAt,
  });
}