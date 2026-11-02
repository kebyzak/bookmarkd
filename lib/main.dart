import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/di.dart';
import 'core/config/app_config.dart';
import 'core/services/secure_session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  final config = AppConfig.fromEnvironment();

  if (config.mode == AppMode.live) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseKey,
      authOptions: const FlutterAuthClientOptions(localStorage: SecureSessionStorage()),
    );
  }

  await configureDependencies(config);
  runApp(BookmarkdApp(fontFamily: GoogleFonts.inter().fontFamily));
}
