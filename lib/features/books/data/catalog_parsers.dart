import 'package:bookmarkd/features/books/domain/book.dart';

Book parseGoogleVolume(Map<String, dynamic> json) {
  final info = (json['volumeInfo'] as Map?)?.cast<String, dynamic>() ?? const {};
  final identifiers = (info['industryIdentifiers'] as List?) ?? const [];
  String? isbn(String type) {
    for (final entry in identifiers.whereType<Map>()) {
      if (entry['type'] == type) return entry['identifier'] as String?;
    }
    return null;
  }

  final images = (info['imageLinks'] as Map?)?.cast<String, dynamic>() ?? const {};
  final rawCover = (images['thumbnail'] ?? images['smallThumbnail']) as String?;

  return Book(
    ids: ExternalIds(googleBooksId: json['id'] as String?, isbn10: isbn('ISBN_10'), isbn13: isbn('ISBN_13')),
    title: _clean(info['title']) ?? 'Untitled',
    subtitle: _clean(info['subtitle']),
    authors: _stringList(info['authors']),
    description: _stripHtml(_clean(info['description'])),
    coverUrl: rawCover == null ? null : _googleCover(rawCover),
    publisher: _clean(info['publisher']),
    publishedDate: _clean(info['publishedDate']),
    pageCount: positiveOrNull(info['pageCount']),
    categories: _stringList(info['categories']).map(_normalizeCategory).toSet().toList(),
    language: _clean(info['language']),
  );
}

Book parseOpenLibraryDoc(Map<String, dynamic> json, {Map<String, dynamic>? work}) {
  final isbns = _stringList(json['isbn']);
  final coverId = json['cover_i'];
  final year = json['first_publish_year'];
  final key = (json['key'] as String?)?.split('/').last;

  return Book(
    ids: ExternalIds(
      openLibraryId: key,
      isbn13: isbns.where((i) => i.length == 13).firstOrNull,
      isbn10: isbns.where((i) => i.length == 10).firstOrNull,
    ),
    title: _clean(json['title']) ?? 'Untitled',
    subtitle: _clean(json['subtitle']),
    description: _openLibraryDescription(work),
    authors: _stringList(json['author_name']),
    coverUrl: coverId is int ? 'https://covers.openlibrary.org/b/id/$coverId-L.jpg?default=false' : null,
    publisher: _stringList(json['publisher']).firstOrNull,
    publishedDate: year is int ? '$year' : null,
    pageCount: positiveOrNull(json['number_of_pages_median']),
    categories: _stringList(json['subject']).take(3).toList(),
    language: _stringList(json['language']).firstOrNull,
  );
}

String? _openLibraryDescription(Map<String, dynamic>? work) {
  final d = work?['description'];
  return _clean(d is Map ? d['value'] : d);
}

List<Book> dedupeBooks(Iterable<Book> books) {
  final seen = <String>{};
  final result = <Book>[];
  for (final book in books) {
    final keys = [
      if (book.ids.googleBooksId != null) 'gb:${book.ids.googleBooksId}',
      if (book.ids.openLibraryId != null) 'ol:${book.ids.openLibraryId}',
      if (book.ids.isbn13 != null) 'i13:${book.ids.isbn13}',
      if (book.ids.isbn10 != null) 'i10:${book.ids.isbn10}',
    ];
    if (keys.any(seen.contains)) continue;
    seen.addAll(keys);
    result.add(book);
  }
  return result;
}

String _googleCover(String url) => url.replaceFirst('http://', 'https://').replaceAll('&edge=curl', '');

String _normalizeCategory(String raw) {
  final parts = raw.split('/').map((p) => p.trim()).where((p) => p.isNotEmpty && p != 'General');
  return parts.isEmpty ? raw.trim() : parts.last;
}

String? _clean(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _stripHtml(String? value) => value?.replaceAll(RegExp(r'<br\s*/?>'), '\n').replaceAll(RegExp(r'<[^>]+>'), '');

List<String> _stringList(Object? value) =>
    value is List ? value.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList() : const [];
