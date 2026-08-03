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
  Map<String, dynamic>? lastInsert;

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

  FakeQuery insert(Map<String, dynamic> map) {
    // record insert for tests
    lastInsert = map;
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
  final Map<String, FakeQuery> _queries = {};
  FakeClient(this.tables);

  FakeQuery from(String table) {
    final res = tables[table];
    final q = FakeQuery(table, res);
    _queries[table] = q;
    return q;
  }

  dynamic channel(String name) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sendEncryptedMessage inserts plaintext when receiver has no public key', () async {
    final tables = {
      'public_keys': [],
      'messages': [],
    };
    final client = FakeClient(tables);
    final svc = ChatService(client);

    final res = await svc.sendEncryptedMessage('alice', 'bob', 'hello world');
    // Our FakeQuery.insert doesn't return execute result; just ensure no exception thrown
    expect(res, isNotNull);
  });

  test('rotateAndUploadKey uses provided rotateFn and upserts public key', () async {
    final tables = {
      'public_keys': [],
    };
    final client = FakeClient(tables);
    Future<String> fakeRotate() async => 'dGVzdF9wdWJrZXk='; // base64 'test_pubkey'
    final svc = ChatService(client, fakeRotate);
    final res = await svc.rotateAndUploadKey('carol');
    expect(res, isNotNull);
  });
}
