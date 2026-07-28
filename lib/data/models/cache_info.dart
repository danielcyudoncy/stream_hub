import 'package:hive/hive.dart';

part 'cache_info.g.dart';

@HiveType(typeId: 2)
class CacheInfo extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int totalSize;

  @HiveField(2)
  final int imageCacheSize;

  @HiveField(3)
  final int temporaryFilesSize;

  @HiveField(4)
  final int metadataCacheSize;

  @HiveField(5)
  final DateTime lastCalculated;

  CacheInfo({
    required this.id,
    required this.totalSize,
    required this.imageCacheSize,
    required this.temporaryFilesSize,
    required this.metadataCacheSize,
    required this.lastCalculated,
  });

  CacheInfo copyWith({
    String? id,
    int? totalSize,
    int? imageCacheSize,
    int? temporaryFilesSize,
    int? metadataCacheSize,
    DateTime? lastCalculated,
  }) {
    return CacheInfo(
      id: id ?? this.id,
      totalSize: totalSize ?? this.totalSize,
      imageCacheSize: imageCacheSize ?? this.imageCacheSize,
      temporaryFilesSize: temporaryFilesSize ?? this.temporaryFilesSize,
      metadataCacheSize: metadataCacheSize ?? this.metadataCacheSize,
      lastCalculated: lastCalculated ?? this.lastCalculated,
    );
  }
}