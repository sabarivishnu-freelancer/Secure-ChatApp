import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:app3/crypto_utils.dart';

void main() {
  test('fingerprintOf returns 8 hex chars for base64 key', () async {
    // sample public key bytes
    final bytes = List<int>.generate(32, (i) => i + 1);
    final b64 = base64Encode(bytes);
    final fp = await fingerprintOf(b64);
    expect(fp.length, 8);
  });
}
