import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/di.dart';
import 'core/config/app_config.dart';
import 'core/services/secure_session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_US');
  final config = AppConfig.fromEnvironment()..ensureComplete();

  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabaseKey,
    authOptions: const FlutterAuthClientOptions(localStorage: SecureSessionStorage()),
  );

  configureDependencies(config);
  runApp(const BookmarkdApp(fontFamily: 'NotoSans'));
}
