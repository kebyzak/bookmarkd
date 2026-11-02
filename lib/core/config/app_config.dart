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
    // An empty `PASSWORD_RESET_REDIRECT=` line still counts as defined, so test for '' instead of defaultValue.
    // Must also be listed under Auth > URL Configuration > Redirect URLs in Supabase.
    passwordResetRedirect: _resetRedirect == '' ? 'com.bookmarkd.bookmarkd://reset-password' : _resetRedirect,
  );

  static const _resetRedirect = String.fromEnvironment('PASSWORD_RESET_REDIRECT');

  final String supabaseUrl;

  /// Publishable (or legacy anon) key. Public by design; RLS protects data.
  final String supabaseKey;
  final String googleBooksApiKey;
  final String passwordResetRedirect;

  /// Fails fast on a build made without `--dart-define-from-file=.env`.
  void ensureComplete() {
    if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are not set. '
        'Build with: flutter run --dart-define-from-file=.env',
      );
    }
  }
}
