// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_info.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CacheInfoAdapter extends TypeAdapter<CacheInfo> {
  @override
  final int typeId = 2;

  @override
  CacheInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CacheInfo(
      id: fields[0] as String,
      totalSize: fields[1] as int,
      imageCacheSize: fields[2] as int,
      temporaryFilesSize: fields[3] as int,
      metadataCacheSize: fields[4] as int,
      lastCalculated: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CacheInfo obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.totalSize)
      ..writeByte(2)
      ..write(obj.imageCacheSize)
      ..writeByte(3)
      ..write(obj.temporaryFilesSize)
      ..writeByte(4)
      ..write(obj.metadataCacheSize)
      ..writeByte(5)
      ..write(obj.lastCalculated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
