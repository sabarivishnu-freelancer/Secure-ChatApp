import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:app3/crypto_keys.dart';
import 'package:app3/e2e.dart';
import 'package:flutter/services.dart';

void main() {
  test('E2E encrypt/decrypt roundtrip', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Mock flutter_secure_storage method channel with in-memory map
    const storageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    final Map<String, String> fakeStorage = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
      final args = call.arguments as Map?;
      switch (call.method) {
        case 'write':
          fakeStorage[args?['key'] as String] = args?['value'] as String? ?? '';
          return null;
        case 'read':
          return fakeStorage[args?['key'] as String];
        case 'delete':
          fakeStorage.remove(args?['key'] as String);
          return null;
        default:
          return null;
      }
    });

    // Generate a keypair for local (acts as both sender & receiver here)
    await CryptoKeys.generateAndStore();
    final pub = await CryptoKeys.getPublicKey();
    expect(pub, isNotNull);
    final pubEncoded = pub != null ? base64Encode(pub.bytes) : '';
    final plaintext = 'hello world';
    final payload = await E2E.encryptFor(plaintext, pubEncoded);
    final decrypted = await E2E.decryptFrom(payload, pubEncoded);
    expect(decrypted, plaintext);
  });
}
