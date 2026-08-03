import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'crypto_utils.dart';
import 'crypto_keys.dart';

import 'e2e.dart';

class ChatService {
  final dynamic _client;
  final Future<String> Function() _rotateFn;

  ChatService([dynamic client, Future<String> Function()? rotateFn]) : _client = client ?? Supabase.instance.client, _rotateFn = rotateFn ?? CryptoKeys.rotateKey;
  final Map<String, String> _pubKeyCache = <String, String>{};
  final Set<String> _seenMessageIds = <String>{};
  final Map<String, Timer> _pollers = <String, Timer>{};
  final Map<String, RealtimeChannel> _realtimeSubs = <String, RealtimeChannel>{};

  // Upload user's public key after signup
  Future<PostgrestResponse> upsertPublicKey(String userId, String publicKey) {
    return _client.from('public_keys').upsert({
      'user_id': userId,
      'public_key': publicKey,
    }).execute();
  }

  /// Regenerate local keypair and upload new public key to `public_keys`.
  Future<PostgrestResponse> rotateAndUploadKey(String userId) async {
    // Generate new keys locally using the injected rotate function.
    final pub = await _rotateFn();
    return upsertPublicKey(userId, pub);
  }

  // Fetch other user's public key
  Future<String?> fetchPublicKey(String userId) async {
    final res = await _client.from('public_keys').select('public_key').eq('user_id', userId).limit(1).execute();
    final data = res.data as List<dynamic>?;
    if (data == null || data.isEmpty) return null;
    return data.first['public_key'] as String?;
  }

  // Store encrypted message
  Future<PostgrestResponse> sendMessage(String senderId, String receiverId, String ciphertext) {
    return _client.from('messages').insert({
      'sender': senderId,
      'receiver': receiverId,
      'ciphertext': ciphertext,
    }).execute();
  }

  // Send plaintext message: fetch receiver public key, encrypt, then insert
  Future<PostgrestResponse> sendEncryptedMessage(String senderId, String receiverId, String plaintext) async {
    final pub = await fetchPublicKey(receiverId);
    final payload = pub != null ? await E2E.encryptFor(plaintext, pub) : jsonEncode({'plaintext': plaintext});
    return sendMessage(senderId, receiverId, payload);
  }

  // Fetch messages for a receiver (recent)
  Future<List<Map<String, dynamic>>> fetchMessagesFor(String receiverId) async {
    final res = await _client.from('messages').select('id, sender, receiver, ciphertext, created_at').or('receiver.eq.$receiverId,receiver.eq.broadcast').order('created_at', ascending: false).limit(100).execute();
    final data = res.data as List<dynamic>?;
    if (data == null) return <Map<String, dynamic>>[];
    return data.cast<Map<String, dynamic>>();
  }

  /// Fetch known contacts (users who uploaded a public key).
  Future<List<Map<String, String>>> fetchContacts({int limit = 100}) async {
    final res = await _client.from('public_keys').select('user_id, public_key').limit(limit).execute();
    final data = res.data as List<dynamic>?;
    if (data == null) return <Map<String, String>>[];
    final List<Map<String, String>> out = <Map<String, String>>[];
    for (final e in data) {
      final m = e as Map<String, dynamic>;
      final uid = m['user_id'] as String? ?? '';
      final pub = m['public_key'] as String? ?? '';
      final fp = await fingerprintOf(pub);

      // Try to fetch a display name from a `profiles` table if available.
      String displayName = '';
      try {
        final p = await _client.from('profiles').select('display_name').eq('id', uid).limit(1).execute();
        final pd = p.data as List<dynamic>?;
        if (pd != null && pd.isNotEmpty) {
          displayName = (pd.first as Map<String, dynamic>)['display_name'] as String? ?? '';
        }
      } catch (_) {
        // ignore – profiles table may not exist
      }

      out.add({'user_id': uid, 'fingerprint': fp, 'display_name': displayName});
    }
    return out;
  }



  // Subscribe to realtime messages for current user (no-op in test environment)
  Future<void> subscribeToMessages(String userId, void Function(Map<String, dynamic>) onMessage, {bool allowPollingFallback = false}) async {
    // Try realtime subscription first (use dynamic to avoid compile-time
    // dependency on specific supabase realtime types). If realtime fails,
    // fall back to polling.
    if (_realtimeSubs.containsKey(userId) || _pollers.containsKey(userId)) return;
    try {
      final channelName = 'messages-$userId';
      final channel = _client.channel(channelName);

      channel.on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(event: 'INSERT', schema: 'public', table: 'messages'),
        (payload, [ref]) async {
          try {
            final m = payload['new'] ?? payload;
            final receiver = m['receiver'] as String? ?? '';
            if (receiver != userId && receiver != 'broadcast') return;
            final id = m['id']?.toString() ?? '';
            if (id.isEmpty || _seenMessageIds.contains(id)) return;
            _seenMessageIds.add(id);

            final sender = m['sender'] as String? ?? '';
            final ciphertext = m['ciphertext'] as String? ?? '';
            String text = '';
            try {
              final decoded = jsonDecode(ciphertext) as Map<String, dynamic>;
              if (decoded.containsKey('plaintext')) {
                text = decoded['plaintext'] as String? ?? '';
              } else {
                final pub = _pubKeyCache[sender] ?? await fetchPublicKey(sender);
                if (pub != null) {
                  _pubKeyCache[sender] = pub;
                  text = await E2E.decryptFrom(ciphertext, pub);
                } else {
                  text = '<encrypted: missing public key>';
                }
              }
            } catch (_) {
              text = ciphertext;
            }

            onMessage(<String, dynamic>{
              'id': id,
              'sender': sender,
              'text': text,
              'created_at': m['created_at'],
            });
          } catch (_) {}
        },
      );

      await channel.subscribe();
      _realtimeSubs[userId] = channel;
      return;
    } catch (_) {
      // realtime not available or subscription failed; optionally fall back to polling
      if (!allowPollingFallback) return;
    }

    if (allowPollingFallback) {
      // Polling fallback
      final timer = Timer.periodic(const Duration(seconds: 3), (_) async {
        try {
          final msgs = await fetchMessagesFor(userId);
          for (final m in msgs.reversed) {
            final id = m['id']?.toString() ?? '';
            if (id.isEmpty || _seenMessageIds.contains(id)) continue;
            _seenMessageIds.add(id);

            final sender = m['sender'] as String? ?? '';
            final ciphertext = m['ciphertext'] as String? ?? '';
            String text = '';
            try {
              final decoded = jsonDecode(ciphertext) as Map<String, dynamic>;
              if (decoded.containsKey('plaintext')) {
                text = decoded['plaintext'] as String? ?? '';
              } else {
                // Need sender public key to decrypt
                final pub = _pubKeyCache[sender] ?? await fetchPublicKey(sender);
                if (pub != null) {
                  _pubKeyCache[sender] = pub;
                  text = await E2E.decryptFrom(ciphertext, pub);
                } else {
                  text = '<encrypted: missing public key>';
                }
              }
            } catch (_) {
              // Not JSON or decryption failed — fallback to raw ciphertext
              text = ciphertext;
            }

            onMessage(<String, dynamic>{
              'id': id,
              'sender': sender,
              'text': text,
              'created_at': m['created_at'],
            });
          }
        } catch (_) {
          // ignore polling errors
        }
      });
      _pollers[userId] = timer;
    }
  }

  /// Stop polling for a given user id.
  void unsubscribe(String userId) {
    final t = _pollers.remove(userId);
    t?.cancel();
    final sub = _realtimeSubs.remove(userId);
    if (sub != null) {
      try {
        sub.unsubscribe();
      } catch (_) {}
    }
    _seenMessageIds.clear();
  }
}
