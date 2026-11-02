enum AppMode { live, demo }

/// Build-time configuration from `--dart-define` / `--dart-define-from-file=.env`.
/// Contains only public client values; no service-role keys ever.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.googleBooksApiKey,
    required this.passwordResetRedirect,
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
        supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
        supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
        googleBooksApiKey: String.fromEnvironment('GOOGLE_BOOKS_API_KEY'),
        passwordResetRedirect: String.fromEnvironment('PASSWORD_RESET_REDIRECT'),
      );

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String googleBooksApiKey;
  final String passwordResetRedirect;

  AppMode get mode => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty ? AppMode.live : AppMode.demo;
}
