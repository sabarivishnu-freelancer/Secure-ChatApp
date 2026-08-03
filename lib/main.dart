import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';
import 'auth.dart';
import 'chat_service.dart';
import 'fingerprint_verify.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  ).then((_) => runApp(const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: _resolveHome(),
    );
  }

  Widget _resolveHome() {
    try {
      // If Supabase isn't initialized in this environment (tests), fall back
      // to the local chat UI so existing tests continue to work.
      final _ = Supabase.instance.client;
      return const AuthGate();
    } catch (_) {
      return const ChatHomePage();
    }
  }
}

class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> {
  static const String _storageKey = 'secure_chat_messages';

  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = <ChatMessage>[
    const ChatMessage(
      text: 'Welcome to Secure Chat',
      isMine: false,
      timestamp: 'Now',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // If a Supabase user exists, subscribe to incoming messages (polling fallback)
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _subscribedUserId = user.id;
        ChatService().subscribeToMessages(user.id, _onIncomingMessage);
      }
    } catch (_) {
      // Supabase not available in this environment (tests/local). Skip subscribing.
    }
  }

  String? _subscribedUserId;

  String _recipientId = 'broadcast';

  void _onIncomingMessage(Map<String, dynamic> msg) async {
    final String sender = msg['sender'] as String? ?? '';
    final String text = msg['text'] as String? ?? '';
    final String ts = msg['created_at']?.toString() ?? DateTime.now().toIso8601String();

    final user = Supabase.instance.client.auth.currentUser;
    final isMine = user != null && sender == user.id;

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isMine: isMine,
          timestamp: ts,
          sender: sender,
        ),
      );
    });

    await _persistMessages();
  }

  Future<void> _loadMessages() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? payload = prefs.getString(_storageKey);

    if (payload == null || payload.isEmpty) {
      return;
    }

    final List<dynamic> decoded = jsonDecode(payload) as List<dynamic>;
    final List<ChatMessage> loadedMessages = decoded
        .map((dynamic item) => ChatMessage.fromJson(item as Map<String, dynamic>))
        .toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _messages
        ..clear()
        ..addAll(loadedMessages);
    });
  }

  Future<void> _persistMessages() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(
        _messages.map((ChatMessage message) => message.toJson()).toList(),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final String message = _controller.text.trim();
    if (message.isEmpty) {
      return;
    }

    setState(() {
      _messages.add(
        ChatMessage(
          text: message,
          isMine: true,
          timestamp: 'Just now',
        ),
      );
      _controller.clear();
    });

    await _persistMessages();

    // If Supabase is available and user signed-in, send encrypted message to backend.
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Use recipient selected in UI
        await ChatService().sendEncryptedMessage(user.id, _recipientId, message);
      }
    } catch (_) {
      // Supabase not initialized or send failed; ignore for local prototype.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Chat'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            tooltip: 'Rotate key',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                final user = Supabase.instance.client.auth.currentUser;
                if (user == null) {
                  messenger.showSnackBar(const SnackBar(content: Text('Not signed in')));
                  return;
                }
                final ok = await showDialog<bool?>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Rotate key'),
                    content: const Text('Generate a new keypair and upload the new public key to your profile? This will invalidate previous keys.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Rotate')),
                    ],
                  ),
                );
                if (!mounted) return;
                if (ok != true) return;
                final res = await ChatService().rotateAndUploadKey(user.id);
                if (res.status >= 200 && res.status < 300) {
                  messenger.showSnackBar(const SnackBar(content: Text('Key rotated and uploaded')));
                } else {
                  messenger.showSnackBar(const SnackBar(content: Text('Key rotation failed')));
                }
              } catch (_) {
                messenger.showSnackBar(const SnackBar(content: Text('Key rotation failed')));
              }
            },
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'Verify fingerprint',
            onPressed: () async {
              Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const FingerprintVerifyPage()));
            },
            icon: const Icon(Icons.fingerprint),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(
              child: Chip(
                label: Text('End-to-end encrypted'),
                avatar: Icon(Icons.shield_outlined, size: 16),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final ChatMessage message = _messages[index];
                  return Align(
                    alignment:
                        message.isMine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: message.isMine
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            message.text,
                            style: TextStyle(
                              color: message.isMine
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                              if (!message.isMine && message.sender.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'From: ${message.sender}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                          const SizedBox(height: 6),
                          Text(
                            message.timestamp,
                            style: TextStyle(
                              fontSize: 11,
                              color: message.isMine
                                  ? Colors.white70
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Pick recipient',
                    icon: const Icon(Icons.person_outline),
                    onPressed: () async {
                      // Show contact picker (contacts are users who uploaded public keys).
                      List<Map<String, String>> contacts = <Map<String, String>>[];
                      try {
                        contacts = await ChatService().fetchContacts();
                      } catch (_) {
                        // ignore
                      }

                      if (!mounted) return;
                      final localContext = context;
                      final selection = await showDialog<String?>(
                        // ignore: use_build_context_synchronously
                        context: localContext,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Select recipient'),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: contacts.isEmpty
                                ? const Text('No contacts available. Enter an ID manually.')
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: contacts.length + 1,
                                    itemBuilder: (c, i) {
                                      if (i == 0) {
                                        return ListTile(
                                          title: const Text('Broadcast (all)'),
                                          leading: const Icon(Icons.public),
                                          onTap: () => Navigator.of(ctx).pop('broadcast'),
                                        );
                                      }
                                      final item = contacts[i - 1];
                                      final id = item['user_id'] ?? '';
                                      final fp = item['fingerprint'] ?? '';
                                      return ListTile(
                                        title: Text(id),
                                        subtitle: fp.isNotEmpty ? Text('fp:$fp') : null,
                                        leading: const Icon(Icons.person),
                                        onTap: () => Navigator.of(ctx).pop(id),
                                      );
                                    },
                                  ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                            FilledButton(
                              onPressed: () async {
                                final parentNavigator = Navigator.of(ctx);
                                final controller = TextEditingController(text: _recipientId);
                                final manual = await showDialog<String?>(
                                  context: context,
                                  builder: (ctx2) => AlertDialog(
                                    title: const Text('Manual recipient ID'),
                                    content: TextField(controller: controller),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(ctx2).pop(), child: const Text('Cancel')),
                                      FilledButton(onPressed: () => Navigator.of(ctx2).pop(controller.text), child: const Text('Set')),
                                    ],
                                  ),
                                );
                                parentNavigator.pop(manual);
                              },
                              child: const Text('Enter ID'),
                            ),
                          ],
                        ),
                      );

                      if (!mounted) return;
                      if (selection != null && selection.isNotEmpty) {
                        setState(() {
                          _recipientId = selection;
                        });
                      }
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _sendMessage,
                    child: const Text('Send'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_subscribedUserId != null) {
      ChatService().unsubscribe(_subscribedUserId!);
    }
    super.dispose();
  }
}

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isMine,
    required this.timestamp,
    this.sender = '',
  });

  final String text;
  final bool isMine;
  final String timestamp;
  final String sender;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] as String,
      isMine: json['isMine'] as bool,
      timestamp: json['timestamp'] as String,
      sender: json['sender'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'text': text,
      'isMine': isMine,
      'timestamp': timestamp,
      'sender': sender,
    };
  }
}
