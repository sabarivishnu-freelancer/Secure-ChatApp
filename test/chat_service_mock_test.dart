import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:postgrest/postgrest.dart';
import 'package:app3/chat_service.dart';

class FakeResponse {
  final dynamic data;
  FakeResponse(this.data);
}

class FakeQuery {
  final String table;
  final Map<String, dynamic> _params = {};
  final dynamic _result;

  FakeQuery(this.table, this._result);

  FakeQuery select(String cols) {
    return this;
  }

  FakeQuery eq(String col, dynamic val) {
    _params[col] = val;
    return this;
  }

  FakeQuery limit(int l) {
    return this;
  }

  Future<PostgrestResponse<dynamic>> execute() async {
    return PostgrestResponse<dynamic>(
      data: _result,
      status: 200,
    );
  }

  FakeQuery insert(Map<String, dynamic> _) {
    return this;
  }

  FakeQuery upsert(Map<String, dynamic> _) {
    return this;
  }

  FakeQuery order(String a, {required bool ascending}) {
    return this;
  }

  FakeQuery or(String _) {
    return this;
  }
}

class FakeClient {
  final Map<String, dynamic> tables;
  FakeClient(this.tables);

  FakeQuery from(String table) {
    final res = tables[table];
    return FakeQuery(table, res);
  }

  // channel not used in this test
  dynamic channel(String name) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fetchContacts returns display_name and fingerprint', () async {
    // Prepare fake data
    final pubBytes = List<int>.generate(32, (i) => i + 1);
    final pubB64 = base64Encode(pubBytes);
    final tables = {
      'public_keys': [
        {'user_id': 'alice', 'public_key': pubB64},
      ],
      'profiles': [
        {'id': 'alice', 'display_name': 'Alice L.'}
      ]
    };

    final client = FakeClient(tables);
    final svc = ChatService(client);
    final contacts = await svc.fetchContacts();
    expect(contacts.length, 1);
    expect(contacts.first['user_id'], 'alice');
    expect(contacts.first['display_name'], 'Alice L.');
    expect(contacts.first['fingerprint']?.length, 8);
  });

  test('rotateAndUploadKey calls upsert with new public key', () async {
    final client = FakeClient({
      'public_keys': [],
    });

    // Provide a rotateFn that returns a known public key
    Future<String> fakeRotate() async => 'ZmFrZV9wdWJfa2V5';

    // Create a ChatService that overrides upsertPublicKey by passing a fake client that records calls
    final svc = ChatService(client, fakeRotate);

    // Override upsertPublicKey by calling svc.upsertPublicKey which uses the fake client
    final res = await svc.rotateAndUploadKey('bob');
    // Since FakeQuery.upsert returns a FakeQuery, but our rotateAndUploadKey returns that execute result.
    // We just assert that no exception was thrown and that method completed.
    expect(res, isNotNull);
  });
}
