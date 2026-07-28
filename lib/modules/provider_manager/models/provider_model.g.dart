// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProviderModelAdapter extends TypeAdapter<ProviderModel> {
  @override
  final int typeId = 0;

  @override
  ProviderModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProviderModel(
      id: fields[0] as String,
      name: fields[1] as String,
      providerType: fields[2] as dynamic,
      serverUrl: fields[3] as String?,
      username: fields[4] as String?,
      password: fields[5] as String?,
      macAddress: fields[6] as String?,
      xmltvUrl: fields[7] as String?,
      notes: fields[8] as String?,
      enabled: fields[9] as bool,
      favorite: fields[10] as bool,
      createdAt: fields[11] as DateTime,
      updatedAt: fields[12] as DateTime,
      lastSync: fields[13] as DateTime?,
      status: fields[14] as dynamic,
      color: fields[15] as String?,
      icon: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProviderModel obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.providerType)
      ..writeByte(3)
      ..write(obj.serverUrl)
      ..writeByte(4)
      ..write(obj.username)
      ..writeByte(5)
      ..write(obj.password)
      ..writeByte(6)
      ..write(obj.macAddress)
      ..writeByte(7)
      ..write(obj.xmltvUrl)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.enabled)
      ..writeByte(10)
      ..write(obj.favorite)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt)
      ..writeByte(13)
      ..write(obj.lastSync)
      ..writeByte(14)
      ..write(obj.status)
      ..writeByte(15)
      ..write(obj.color)
      ..writeByte(16)
      ..write(obj.icon);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProviderModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
