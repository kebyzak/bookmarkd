class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseKey,
    required this.googleBooksApiKey,
    required this.passwordResetRedirect,
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://satnhgvrjuqtvljakgwk.supabase.co'),
    supabaseKey: String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'sb_publishable_4ArxASyPBkS_9eQvV5TYrg_hOaMY7Sv',
      ),
    ),
    googleBooksApiKey: String.fromEnvironment('GOOGLE_BOOKS_API_KEY'),
    passwordResetRedirect: _resetRedirect == '' ? 'com.bookmarkd.bookmarkd://reset-password' : _resetRedirect,
  );

  static const _resetRedirect = String.fromEnvironment('PASSWORD_RESET_REDIRECT');

  final String supabaseUrl;
  final String supabaseKey;
  final String googleBooksApiKey;
  final String passwordResetRedirect;

  void ensureComplete() {
    if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are not set. '
        'Set them in AppConfig or pass them with --dart-define.',
      );
    }
  }
}
