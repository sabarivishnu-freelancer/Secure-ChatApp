import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CryptoKeys {
  static const _storage = FlutterSecureStorage();
  static const _privateKeyKey = 'e2e_private_key';
  static const _publicKeyKey = 'e2e_public_key';

  // Generate an X25519 keypair and store private key securely
  static Future<SimpleKeyPair> generateAndStore() async {
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    final keyPairData = await keyPair.extract();
    final privateBytes = keyPairData.bytes;
    final publicBytes = keyPairData.publicKey.bytes;
    await _storage.write(key: _privateKeyKey, value: base64Encode(privateBytes));
    await _storage.write(key: _publicKeyKey, value: base64Encode(publicBytes));
    return keyPair;
  }

  /// Regenerate keys and return the new public key as base64.
  static Future<String> rotateKey() async {
    final kp = await generateAndStore();
    final kpData = await kp.extract();
    final pub = kpData.publicKey.bytes;
    final b64 = base64Encode(pub);
    await _storage.write(key: _publicKeyKey, value: b64);
    return b64;
  }

  // Extract public key from stored private key
  static Future<SimplePublicKey?> getPublicKey() async {
    final encoded = await _storage.read(key: _publicKeyKey);
    if (encoded == null) return null;
    final bytes = base64Decode(encoded);
    return SimplePublicKey(bytes, type: KeyPairType.x25519);
  }

  static Future<SimpleKeyPair?> loadPrivateKey() async {
    final encoded = await _storage.read(key: _privateKeyKey);
    if (encoded == null) return null;
    final privateBytes = base64Decode(encoded);
    final pubEncoded = await _storage.read(key: _publicKeyKey);
    if (pubEncoded == null) return null;
    final publicBytes = base64Decode(pubEncoded);
    return SimpleKeyPairData(privateBytes, publicKey: SimplePublicKey(publicBytes, type: KeyPairType.x25519), type: KeyPairType.x25519);
  }

  /// Return stored public key as base64 string, or null if not present.
  static Future<String?> getPublicKeyBase64() async {
    return await _storage.read(key: _publicKeyKey);
  }
}
