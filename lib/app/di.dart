import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../core/network/http_client.dart';
import '../core/repositories.dart';
import '../core/services/recent_searches_store.dart';
import '../features/auth/data/supabase_auth_repository.dart';
import '../features/books/data/catalog_repository_impl.dart';
import '../features/books/data/supabase_book_repository.dart';
import '../features/library/data/supabase_library_repository.dart';
import '../features/profile/data/supabase_profile_repository.dart';
import '../features/reviews/data/supabase_review_repository.dart';
import '../features/social/data/supabase_activity_repository.dart';

final sl = GetIt.instance;

/// Registers every dependency once. Call after `Supabase.initialize`.
void configureDependencies(AppConfig config) {
  sl
    ..registerSingleton<CatalogRepository>(HttpCatalogRepository(createHttpClient(), apiKey: config.googleBooksApiKey))
    ..registerLazySingleton(() => RecentSearchesStore(SharedPreferencesAsync()));

  final client = Supabase.instance.client;
  final profiles = SupabaseProfileRepository(client);
  sl
    ..registerSingleton<AuthRepository>(
      SupabaseAuthRepository(client, passwordResetRedirect: config.passwordResetRedirect),
    )
    ..registerSingleton<ProfileRepository>(profiles)
    ..registerSingleton<SocialRepository>(profiles)
    ..registerSingleton<BookRepository>(SupabaseBookRepository(client))
    ..registerSingleton<LibraryRepository>(SupabaseLibraryRepository(client))
    ..registerSingleton<ReviewRepository>(SupabaseReviewRepository(client))
    ..registerSingleton<ActivityRepository>(SupabaseActivityRepository(client));
}
