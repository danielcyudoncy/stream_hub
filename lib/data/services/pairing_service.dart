import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../../core/logging/logging_service.dart';
import '../../modules/provider_manager/models/provider_enums.dart';
import 'firebase_service.dart';

class PairingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LoggingService _logger = Get.find<LoggingService>();

  static const String _collection = 'pairings';
  static const String _baseUrl = 'https://stream-hub-fecfa.web.app/pair.html';

  static const int _codeLength = 6;
  static const String _charset = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const Duration _expiryDuration = Duration(minutes: 5);

  bool get isAvailable {
    final service = Get.isRegistered<FirebaseService>()
        ? Get.find<FirebaseService>()
        : null;
    return service?.isAvailable ?? false;
  }

  String generateCode() {
    final random = Random.secure();
    return String.fromCharCodes(
      List<int>.generate(_codeLength, (_) {
        return _charset.codeUnitAt(random.nextInt(_charset.length));
      }),
    );
  }

  String getPairingUrl(String code) => '$_baseUrl?code=$code';

  List<Map<String, dynamic>> getFieldDefinitions(ProviderType type) {
    return switch (type) {
      ProviderType.m3u => [
        {'key': 'name', 'label': 'Provider Name', 'type': 'text', 'required': true, 'multiline': false},
        {'key': 'serverUrl', 'label': 'M3U URL', 'type': 'url', 'required': true, 'multiline': false},
        {'key': 'xmltvUrl', 'label': 'XMLTV URL (optional)', 'type': 'url', 'required': false, 'multiline': false},
        {'key': 'notes', 'label': 'Notes (optional)', 'type': 'text', 'required': false, 'multiline': true},
      ],
      ProviderType.xtream => [
        {'key': 'name', 'label': 'Provider Name', 'type': 'text', 'required': true, 'multiline': false},
        {'key': 'serverUrl', 'label': 'Server URL', 'type': 'url', 'required': true, 'multiline': false},
        {'key': 'username', 'label': 'Username', 'type': 'text', 'required': true, 'multiline': false},
        {'key': 'password', 'label': 'Password', 'type': 'password', 'required': true, 'multiline': false},
        {'key': 'xmltvUrl', 'label': 'XMLTV URL (optional)', 'type': 'url', 'required': false, 'multiline': false},
        {'key': 'notes', 'label': 'Notes (optional)', 'type': 'text', 'required': false, 'multiline': true},
      ],
      ProviderType.stalker => [
        {'key': 'name', 'label': 'Provider Name', 'type': 'text', 'required': true, 'multiline': false},
        {'key': 'serverUrl', 'label': 'Portal URL', 'type': 'url', 'required': true, 'multiline': false},
        {'key': 'macAddress', 'label': 'MAC Address', 'type': 'text', 'required': true, 'multiline': false},
        {'key': 'xmltvUrl', 'label': 'XMLTV URL (optional)', 'type': 'url', 'required': false, 'multiline': false},
        {'key': 'notes', 'label': 'Notes (optional)', 'type': 'text', 'required': false, 'multiline': true},
      ],
      ProviderType.xmltv => [
        {'key': 'name', 'label': 'Provider Name', 'type': 'text', 'required': true, 'multiline': false},
        {'key': 'xmltvUrl', 'label': 'XMLTV URL', 'type': 'url', 'required': true, 'multiline': false},
        {'key': 'notes', 'label': 'Notes (optional)', 'type': 'text', 'required': false, 'multiline': true},
      ],
      ProviderType.custom => [
        {'key': 'name', 'label': 'Provider Name', 'type': 'text', 'required': true, 'multiline': false},
        {'key': 'serverUrl', 'label': 'Server URL', 'type': 'url', 'required': false, 'multiline': false},
        {'key': 'username', 'label': 'Username', 'type': 'text', 'required': false, 'multiline': false},
        {'key': 'password', 'label': 'Password', 'type': 'password', 'required': false, 'multiline': false},
        {'key': 'macAddress', 'label': 'MAC Address', 'type': 'text', 'required': false, 'multiline': false},
        {'key': 'xmltvUrl', 'label': 'XMLTV URL (optional)', 'type': 'url', 'required': false, 'multiline': false},
        {'key': 'notes', 'label': 'Notes (optional)', 'type': 'text', 'required': false, 'multiline': true},
      ],
    };
  }

  Future<String> createPairing(ProviderType providerType) async {
    final code = generateCode();
    final now = DateTime.now();
    final docRef = _firestore.collection(_collection).doc(code);

    await docRef.set({
      'code': code,
      'providerType': providerType.name,
      'fieldDefs': getFieldDefinitions(providerType),
      'formData': null,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(now.add(_expiryDuration)),
      'status': 'pending',
    });

    _logger.info('Pairing created: $code for ${providerType.name}', tag: 'PairingService');
    return code;
  }

  Stream<Map<String, dynamic>?> watchFormData(String code) {
    final docRef = _firestore.collection(_collection).doc(code);
    return docRef.snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) return null;
      final status = data['status'] as String?;
      if (status == 'completed') {
        return Map<String, dynamic>.from(data['formData'] ?? {});
      }
      return null;
    });
  }

  Future<void> markCompleted(String code) async {
    await _firestore.collection(_collection).doc(code).update({
      'status': 'completed',
      'completedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deletePairing(String code) async {
    await _firestore.collection(_collection).doc(code).delete();
    _logger.info('Pairing deleted: $code', tag: 'PairingService');
  }

  Stream<int> watchCountdown(String code) {
    final docRef = _firestore.collection(_collection).doc(code);
    return docRef.snapshots().map((snapshot) {
      if (!snapshot.exists) return 0;
      final data = snapshot.data();
      if (data == null) return 0;
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      if (expiresAt == null) return 0;
      final remaining = (expiresAt.difference(DateTime.now()).inSeconds).clamp(0, _expiryDuration.inSeconds);
      return remaining;
    });
  }

  void dispose() {
    // No persistent subscriptions held at the service level;
    // the PairingDialog manages its own StreamSubscriptions.
  }
}
