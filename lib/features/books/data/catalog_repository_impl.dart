import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/network/http_client.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/books/domain/catalog_query.dart';
import 'package:dio/dio.dart';

import 'catalog_parsers.dart';

class HttpCatalogRepository implements CatalogRepository {
  HttpCatalogRepository(this._dio, {this.apiKey = ''});

  final Dio _dio;
  final String apiKey;

  @override
  Future<CatalogPage> search(CatalogQuery query, {int startIndex = 0}) async {
    if (!query.isSearchable) return (books: const <Book>[], fetched: 0);
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
      'isbn' => _first((await search(CatalogQuery.parse(value, mode: SearchMode.isbn))).books),
      'ol' => _first((await _searchOpenLibrary(CatalogQuery.parse('key:/works/$value'), 0)).books),
      _ => throw const AppFailure.notFound(),
    };
  }

  Book _first(List<Book> books) => books.isEmpty ? throw const AppFailure.notFound() : books.first;

  Future<CatalogPage> _searchGoogle(CatalogQuery query, int startIndex) async {
    final json = await _get('https://www.googleapis.com/books/v1/volumes', {
      'q': query.googleQuery,
      'startIndex': '$startIndex',
      'maxResults': '$catalogPageSize',
      'printType': 'books',
      if (apiKey.isNotEmpty) 'key': apiKey,
    });
    final items = (json['items'] as List?) ?? const [];
    return (books: dedupeBooks(items.whereType<Map<String, dynamic>>().map(parseGoogleVolume)), fetched: items.length);
  }

  Future<Book> _googleVolume(String id) async {
    final json = await _get('https://www.googleapis.com/books/v1/volumes/$id', {if (apiKey.isNotEmpty) 'key': apiKey});
    return parseGoogleVolume(json);
  }

  Future<CatalogPage> _searchOpenLibrary(CatalogQuery query, int startIndex) async {
    final json = await _get('https://openlibrary.org/search.json', {
      ...query.openLibraryParams,
      'offset': '$startIndex',
      'limit': '$catalogPageSize',
      'fields':
          'key,title,subtitle,author_name,first_publish_year,isbn,number_of_pages_median,'
          'cover_i,publisher,subject,language',
    });
    final docs = (json['docs'] as List?) ?? const [];
    return (books: dedupeBooks(docs.whereType<Map<String, dynamic>>().map(parseOpenLibraryDoc)), fetched: docs.length);
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
