 # Secure ChatApp (Prototype)

 This is a Flutter prototype for a secure, multi-user chat with Supabase authentication and Postgres storage. It implements client-side end-to-end encryption (X25519 key agreement + ChaCha20-Poly1305 AEAD).

 Quick dev steps

 1. Set Supabase config in `lib/supabase_config.dart`.
 2. Create the database tables from `supabase/schema.sql` in your Supabase project.
 3. Run the app locally:

 ```powershell
 flutter pub get
 flutter run -d chrome
 ```

To run the app locally without committing keys, provide Supabase values at build time using `--dart-define`:

```powershell
# Example (replace with your values):
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=https://your-project.supabase.co \
	--dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Alternatively, set up CI secrets or other secure delivery for production keys.

 Running tests

 ```powershell
 flutter test
 ```

 Notes and security

 - Do not commit `supabase_config.dart` with real keys. Use environment variables or CI secrets instead.
 - The app stores private keys in `flutter_secure_storage`. For production, consider platform-specific hardened storage and key rotation.
 - Realtime: the app uses Supabase realtime when available; otherwise it falls back to polling for compatibility in tests.

 Files of interest

 - `lib/e2e.dart` — encrypt/decrypt helpers
 - `lib/crypto_keys.dart` — key generation and secure storage
 - `lib/chat_service.dart` — Supabase interactions, realtime/polling
 - `lib/auth.dart` — sign-up/sign-in with public-key upload
 - `supabase/schema.sql` — SQL schema for `public_keys` and `messages`

 If you want, I can:
 - Switch the dynamic realtime code to the typed Supabase realtime API (confirm `supabase_flutter` version), or
 - Add an address book UI that lists Supabase users with public keys.
