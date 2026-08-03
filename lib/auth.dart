import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'main.dart';
import 'chat_service.dart';
import 'crypto_keys.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  User? _user;

  @override
  void initState() {
    super.initState();
    try {
      _user = Supabase.instance.client.auth.currentUser;
      Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        setState(() {
          _user = Supabase.instance.client.auth.currentUser;
        });
      });
    } catch (_) {
      // Supabase not initialized (tests / offline). Fall back to local mode.
      _user = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user != null) {
      return const ChatHomePage();
    }

    return const LoginScreen();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _loading = false;

  Future<void> _signIn() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final res = await Supabase.instance.client.auth.signInWithPassword(
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    if (res.session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign-in failed')),
      );
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _signUp() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final res = await Supabase.instance.client.auth.signUp(
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    if (res.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign-up failed')),
      );
    } else {
      // Generate an X25519 keypair and upload public key to Supabase
      try {
        await CryptoKeys.generateAndStore();
        final pub = await CryptoKeys.getPublicKey();
        if (!mounted) return;
        if (pub != null && res.user != null) {
          final b64 = base64Encode(pub.bytes);
          await ChatService().upsertPublicKey(res.user!.id, b64);
        }
      } catch (e) {
        if (!mounted) return;
        // Non-fatal: inform user but allow signup to succeed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Warning: key upload failed: $e')),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign-up successful — check email to confirm if required')),
      );
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')), 
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _signIn,
                    child: _loading ? const CircularProgressIndicator() : const Text('Sign in'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : _signUp,
                    child: const Text('Sign up'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
