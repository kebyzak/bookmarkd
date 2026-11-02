import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/http_client.dart';
import '../../../core/repositories.dart';
import '../domain/book.dart';
import '../domain/catalog_query.dart';
import 'catalog_parsers.dart';

/// Google Books first; Open Library when Google fails (network, 5xx, 429).
class HttpCatalogRepository implements CatalogRepository {
  HttpCatalogRepository(this._dio, {this.apiKey = ''});

  final Dio _dio;
  final String apiKey;
  static const pageSize = 20;

  @override
  Future<List<Book>> search(CatalogQuery query, {int startIndex = 0}) async {
    if (!query.isSearchable) return const [];
    try {
      return await _searchGoogle(query, startIndex);
    } on AppFailure catch (googleFailure) {
      if (googleFailure.kind == FailureKind.unknown) rethrow;
      try {
        return await _searchOpenLibrary(query, startIndex);
      } on AppFailure {
        throw googleFailure;
      }
    }
  }

  @override
  Future<Book> lookup(String catalogKey) async {
    final sep = catalogKey.indexOf(':');
    if (sep < 0) throw const AppFailure.notFound();
    final scheme = catalogKey.substring(0, sep);
    final value = catalogKey.substring(sep + 1);
    return switch (scheme) {
      'gb' => _googleVolume(value),
      'isbn' => _first(await search(CatalogQuery.parse(value, mode: SearchMode.isbn))),
      'ol' => _first(await _searchOpenLibrary(CatalogQuery.parse('key:/works/$value'), 0)),
      _ => throw const AppFailure.notFound(),
    };
  }

  Book _first(List<Book> books) => books.isEmpty ? throw const AppFailure.notFound() : books.first;

  Future<List<Book>> _searchGoogle(CatalogQuery query, int startIndex) async {
    final json = await _get('https://www.googleapis.com/books/v1/volumes', {
      'q': query.googleQuery,
      'startIndex': '$startIndex',
      'maxResults': '$pageSize',
      'printType': 'books',
      if (apiKey.isNotEmpty) 'key': apiKey,
    });
    final items = (json['items'] as List?) ?? const [];
    return dedupeBooks(items.whereType<Map<String, dynamic>>().map(parseGoogleVolume));
  }

  Future<Book> _googleVolume(String id) async {
    final json = await _get('https://www.googleapis.com/books/v1/volumes/$id', {
      if (apiKey.isNotEmpty) 'key': apiKey,
    });
    return parseGoogleVolume(json);
  }

  Future<List<Book>> _searchOpenLibrary(CatalogQuery query, int startIndex) async {
    final json = await _get('https://openlibrary.org/search.json', {
      ...query.openLibraryParams,
      'offset': '$startIndex',
      'limit': '$pageSize',
      'fields': 'key,title,subtitle,author_name,first_publish_year,isbn,number_of_pages_median,'
          'cover_i,publisher,subject,language',
    });
    final docs = (json['docs'] as List?) ?? const [];
    return dedupeBooks(docs.whereType<Map<String, dynamic>>().map(parseOpenLibraryDoc));
  }

  Future<Map<String, dynamic>> _get(String url, Map<String, String> params) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(url, queryParameters: params);
      return response.data ?? const {};
    } catch (e) {
      throw mapDioError(e);
    }
  }
}
