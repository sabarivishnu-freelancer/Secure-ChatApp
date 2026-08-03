import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'crypto_keys.dart';

/// Perform X25519 key agreement and AEAD encryption using ChaCha20-Poly1305.
class E2E {
  static final _x25519 = X25519();
  static final _aead = Chacha20.poly1305Aead();

  // Derive a symmetric key (32 bytes) from local private key and remote public key
  static Future<SecretKey> _deriveSharedKey(SimplePublicKey remotePublic) async {
    final localPair = await CryptoKeys.loadPrivateKey();
    if (localPair == null) {
      throw StateError('Local private key not available');
    }
    final shared = await _x25519.sharedSecretKey(keyPair: localPair, remotePublicKey: remotePublic);
    final sharedBytes = await shared.extractBytes();
    final hash = await Sha256().hash(sharedBytes);
    return SecretKey(hash.bytes);
  }

  // Encrypt a plaintext for the recipient public key (base64)
  static Future<String> encryptFor(String plaintext, String recipientPublicBase64) async {
    final remoteBytes = base64Decode(recipientPublicBase64);
    final remotePub = SimplePublicKey(remoteBytes, type: KeyPairType.x25519);
    final key = await _deriveSharedKey(remotePub);
    final secretBox = await _aead.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
    );
    final payload = {
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };
    return jsonEncode(payload);
  }

  // Decrypt a ciphertext JSON produced by `encryptFor`, given sender public key (base64)
  static Future<String> decryptFrom(String ciphertextJson, String senderPublicBase64) async {
    final data = jsonDecode(ciphertextJson) as Map<String, dynamic>;
    final nonce = base64Decode(data['nonce'] as String);
    final ct = base64Decode(data['ciphertext'] as String);
    final mac = base64Decode(data['mac'] as String);
    final remotePub = SimplePublicKey(base64Decode(senderPublicBase64), type: KeyPairType.x25519);
    final key = await _deriveSharedKey(remotePub);
    final secretBox = SecretBox(
      ct,
      nonce: nonce,
      mac: Mac(mac),
    );
    final clear = await _aead.decrypt(secretBox, secretKey: key);
    return utf8.decode(clear);
  }
}
