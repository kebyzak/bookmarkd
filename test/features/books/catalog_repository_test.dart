import 'dart:convert';
import 'dart:typed_data';

import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/features/books/data/catalog_repository_impl.dart';
import 'package:bookmarkd/features/books/domain/catalog_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers requests by host with a canned status and JSON body.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.responses);
  final Map<String, (int, Object)> responses;
  final requested = <Uri>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body, Future<void>? cancel) async {
    requested.add(options.uri);
    final (status, json) = responses[options.uri.host]!;
    return ResponseBody.fromString(jsonEncode(json), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

HttpCatalogRepository repoWith(FakeAdapter adapter) => HttpCatalogRepository(Dio()..httpClientAdapter = adapter);

const googleOk = {
  'items': [
    {
      'id': 'g1',
      'volumeInfo': {'title': 'Dune', 'authors': ['Frank Herbert']},
    },
  ],
};

const openLibraryOk = {
  'docs': [
    {'key': '/works/OL1W', 'title': 'Dune', 'author_name': ['Frank Herbert']},
  ],
};

void main() {
  test('returns Google Books results when Google answers', () async {
    final adapter = FakeAdapter({'www.googleapis.com': (200, googleOk)});
    final books = await repoWith(adapter).search(CatalogQuery.parse('dune'));
    expect(books.single.key, 'gb:g1');
  });

  test('falls back to Open Library when Google is rate limited', () async {
    final adapter = FakeAdapter({
      'www.googleapis.com': (429, {}),
      'openlibrary.org': (200, openLibraryOk),
    });
    final books = await repoWith(adapter).search(CatalogQuery.parse('dune', mode: SearchMode.title));
    expect(books.single.key, 'ol:OL1W');
    expect(adapter.requested.last.queryParameters['title'], 'dune');
  });

  test('reports the original failure when both catalogs fail', () async {
    final adapter = FakeAdapter({
      'www.googleapis.com': (429, {}),
      'openlibrary.org': (503, {}),
    });
    expect(
      repoWith(adapter).search(CatalogQuery.parse('dune')),
      throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.rateLimited)),
    );
  });

  test('does not call the network for unsearchable input', () async {
    final adapter = FakeAdapter({});
    expect(await repoWith(adapter).search(CatalogQuery.parse(' ')), isEmpty);
    expect(adapter.requested, isEmpty);
  });
}
