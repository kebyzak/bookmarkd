import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_failure.dart';

/// Runs a Supabase call and converts every error into an [AppFailure].
Future<T> guardSupabase<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on AppFailure {
    rethrow;
  } on AuthException catch (e) {
    throw AppFailure(FailureKind.unauthorized, e.message);
  } on PostgrestException catch (e) {
    throw switch (e.code) {
      '23505' => const AppFailure.conflict('That already exists.'),
      '22023' || '23514' => AppFailure.validation(e.message),
      '42501' => const AppFailure.unauthorized("You don't have permission to do that."),
      'PGRST116' || 'P0002' => const AppFailure.notFound(),
      _ => const AppFailure.unknown(),
    };
  } on FunctionException catch (e) {
    throw switch (e.status) {
      401 => const AppFailure.unauthorized(),
      404 => const AppFailure.notFound("The catalog doesn't have this book any more."),
      _ => const AppFailure.unknown(),
    };
  } on StorageException catch (e) {
    throw AppFailure(FailureKind.unknown, 'Upload failed: ${e.message}');
  } on SocketException {
    throw const AppFailure.network();
  } on TimeoutException {
    throw const AppFailure.network();
  } catch (_) {
    throw const AppFailure.unknown();
  }
}
