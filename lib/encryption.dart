import 'dart:convert';

// NOTE: This is a placeholder encryption shim for the prototype. Replace with
// real E2E encryption (X25519 key agreement + AEAD) before production.

String encryptMessagePlaceholder(String plaintext) {
  final bytes = utf8.encode(plaintext);
  return base64Encode(bytes);
}

String decryptMessagePlaceholder(String ciphertext) {
  try {
    final bytes = base64Decode(ciphertext);
    return utf8.decode(bytes);
  } catch (_) {
    return '<decryption_failed>';
  }
}
