enum AppMode { live, demo }

/// Build-time configuration from `--dart-define` / `--dart-define-from-file=.env`.
/// Contains only public client values; no service-role keys ever.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseKey,
    required this.googleBooksApiKey,
    required this.passwordResetRedirect,
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseKey: String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
    ),
    googleBooksApiKey: String.fromEnvironment('GOOGLE_BOOKS_API_KEY'),
    passwordResetRedirect: String.fromEnvironment('PASSWORD_RESET_REDIRECT'),
  );

  final String supabaseUrl;

  /// Publishable (or legacy anon) key. Public by design; RLS protects data.
  final String supabaseKey;
  final String googleBooksApiKey;
  final String passwordResetRedirect;

  AppMode get mode => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty ? AppMode.live : AppMode.demo;
}
