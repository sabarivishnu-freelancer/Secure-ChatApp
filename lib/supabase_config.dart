class SupabaseConfig {
  // Prefer providing these at build time using `--dart-define` so keys
  // are not committed to source control. Example:
  // flutter run -d chrome --dart-define=SUPABASE_URL=https://<proj>.supabase.co \
  //   --dart-define=SUPABASE_ANON_KEY=<anon-key>
  // Defaults below are intentionally placeholders and MUST be overridden
  // for a working app.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key',
  );
}
