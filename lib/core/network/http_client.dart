import 'package:dio/dio.dart';

import '../errors/app_failure.dart';

Dio createHttpClient() => Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 12),
    headers: {'User-Agent': 'Bookmarkd/1.0 (Flutter; contact: support@bookmarkd.app)'},
  ),
);

/// Maps a transport error to an [AppFailure].
AppFailure mapDioError(Object error) {
  if (error is! DioException) return AppFailure.from(error);
  final status = error.response?.statusCode;
  if (status == 429) return const AppFailure.rateLimited();
  if (status == 404) return const AppFailure.notFound();
  return switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout => const AppFailure.network(),
    _ when status != null && status >= 500 => const AppFailure.network('The book catalog is having trouble.'),
    _ => const AppFailure.unknown(),
  };
}
