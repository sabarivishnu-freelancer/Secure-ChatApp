import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Compute a short hex fingerprint (8 chars) for a base64-encoded public key.
Future<String> fingerprintOf(String publicKeyBase64) async {
  if (publicKeyBase64.isEmpty) return '';
  try {
    final bytes = base64Decode(publicKeyBase64);
    final hash = await Sha256().hash(bytes);
    final hex = hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return hex.substring(0, 8);
  } catch (_) {
    if (publicKeyBase64.length <= 8) return publicKeyBase64;
    return publicKeyBase64.substring(publicKeyBase64.length - 8);
  }
}
