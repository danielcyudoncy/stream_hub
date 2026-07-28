import 'package:hive/hive.dart';

import 'provider_enums.dart';

part 'provider_model.g.dart';

@HiveType(typeId: 0)
class ProviderModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  ProviderType providerType;

  @HiveField(3)
  String? serverUrl;

  @HiveField(4)
  String? username;

  @HiveField(5)
  String? password;

  @HiveField(6)
  String? macAddress;

  @HiveField(7)
  String? xmltvUrl;

  @HiveField(8)
  String? notes;

  @HiveField(9)
  bool enabled;

  @HiveField(10)
  bool favorite;

  @HiveField(11)
  final DateTime createdAt;

  @HiveField(12)
  DateTime updatedAt;

  @HiveField(13)
  DateTime? lastSync;

  @HiveField(14)
  ProviderStatus status;

  @HiveField(15)
  String? color;

  @HiveField(16)
  String? icon;

  ProviderModel({
    required this.id,
    required this.name,
    required this.providerType,
    this.serverUrl,
    this.username,
    this.password,
    this.macAddress,
    this.xmltvUrl,
    this.notes,
    this.enabled = true,
    this.favorite = false,
    required this.createdAt,
    required this.updatedAt,
    this.lastSync,
    this.status = ProviderStatus.inactive,
    this.color,
    this.icon,
  });

  ProviderModel copyWith({
    String? name,
    ProviderType? providerType,
    String? serverUrl,
    String? username,
    String? password,
    String? macAddress,
    String? xmltvUrl,
    String? notes,
    bool? enabled,
    bool? favorite,
    DateTime? updatedAt,
    DateTime? lastSync,
    ProviderStatus? status,
    String? color,
    String? icon,
  }) {
    return ProviderModel(
      id: id,
      name: name ?? this.name,
      providerType: providerType ?? this.providerType,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      macAddress: macAddress ?? this.macAddress,
      xmltvUrl: xmltvUrl ?? this.xmltvUrl,
      notes: notes ?? this.notes,
      enabled: enabled ?? this.enabled,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSync: lastSync ?? this.lastSync,
      status: status ?? this.status,
      color: color ?? this.color,
      icon: icon ?? this.icon,
    );
  }
}
