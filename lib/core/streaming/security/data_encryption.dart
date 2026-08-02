import 'dart:convert';
import 'dart:math';

/// Obfuscates sensitive persisted data (cookies, tokens, credentials).
///
/// This is a local, keyed transformation intended to prevent casual exposure
/// of secrets in Hive storage. Production deployments should replace this with
/// platform secure storage (Keychain / Android Keystore / flutter_secure_storage)
/// via the same [DataEncryption] interface.
abstract class DataEncryption {
  String encrypt(String plainText);
  String decrypt(String cipherText);
}

/// Keyed XOR + base64 obfuscation. The key is derived from a per-install random
/// value so ciphertext differs between installs.
class LocalDataObfuscator implements DataEncryption {
  final List<int> _key;

  LocalDataObfuscator(List<int> key)
    : _key = List.unmodifiable(key.isNotEmpty ? key : [1, 3, 7, 13]);

  factory LocalDataObfuscator.fromSeed(int seed) {
    final random = Random(seed);
    return LocalDataObfuscator(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
  }

  @override
  String encrypt(String plainText) {
    if (plainText.isEmpty) return plainText;
    final bytes = utf8.encode(plainText);
    final out = List<int>.generate(bytes.length, (i) {
      return bytes[i] ^ _key[i % _key.length];
    });
    return base64Encode(out);
  }

  @override
  String decrypt(String cipherText) {
    if (cipherText.isEmpty) return cipherText;
    final bytes = base64Decode(cipherText);
    final out = List<int>.generate(bytes.length, (i) {
      return bytes[i] ^ _key[i % _key.length];
    });
    return utf8.decode(out);
  }
}
