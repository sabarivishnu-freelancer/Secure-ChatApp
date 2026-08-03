import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'crypto_utils.dart';
import 'crypto_keys.dart';

class FingerprintVerifyPage extends StatefulWidget {
  const FingerprintVerifyPage({super.key});

  @override
  State<FingerprintVerifyPage> createState() => _FingerprintVerifyPageState();
}

class _FingerprintVerifyPageState extends State<FingerprintVerifyPage> {
  String _fingerprint = '';
  String _other = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFingerprint();
  }

  Future<void> _loadFingerprint() async {
    try {
      final pub = await CryptoKeys.getPublicKeyBase64();
      if (!mounted) return;
      if (pub == null) {
        setState(() {
          _fingerprint = '<no local public key>';
          _loading = false;
        });
        return;
      }
      final fp = await fingerprintOf(pub);
      if (!mounted) return;
      setState(() {
        _fingerprint = fp;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fingerprint = '<error>';
        _loading = false;
      });
    }
  }

  void _compare() {
    final match = _other.trim() == _fingerprint;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verification'),
        content: Text(match ? 'Fingerprints match' : 'Fingerprints do NOT match'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Fingerprint')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Local fingerprint', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _loading
                  ? const CircularProgressIndicator()
                  : SelectableText(_fingerprint, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              const Text('Enter remote fingerprint to verify'),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'abcdef12'),
                onChanged: (v) => _other = v,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton(onPressed: _compare, child: const Text('Compare')),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(ClipboardData(text: _fingerprint));
                      if (!mounted) return;
                      messenger.showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                    },
                    child: const Text('Copy'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
