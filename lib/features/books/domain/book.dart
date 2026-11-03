import 'package:equatable/equatable.dart';

class ExternalIds extends Equatable {
  const ExternalIds({this.googleBooksId, this.openLibraryId, this.isbn10, this.isbn13});

  final String? googleBooksId;
  final String? openLibraryId;
  final String? isbn10;
  final String? isbn13;

  String? get catalogKey {
    if (googleBooksId != null) return 'gb:$googleBooksId';
    if (openLibraryId != null) return 'ol:$openLibraryId';
    if (isbn13 != null) return 'isbn:$isbn13';
    if (isbn10 != null) return 'isbn:$isbn10';
    return null;
  }

  Map<String, dynamic> toJson() => {
    'google_books_id': googleBooksId,
    'open_library_id': openLibraryId,
    'isbn_10': isbn10,
    'isbn_13': isbn13,
  };

  factory ExternalIds.fromJson(Map<String, dynamic> json) => ExternalIds(
    googleBooksId: json['google_books_id'] as String?,
    openLibraryId: json['open_library_id'] as String?,
    isbn10: json['isbn_10'] as String?,
    isbn13: json['isbn_13'] as String?,
  );

  @override
  List<Object?> get props => [googleBooksId, openLibraryId, isbn10, isbn13];
}

class Book extends Equatable {
  const Book({
    this.id,
    this.editionId,
    required this.ids,
    required this.title,
    required this.authors,
    this.subtitle,
    this.description,
    this.coverUrl,
    this.publisher,
    this.publishedDate,
    this.pageCount,
    this.categories = const [],
    this.language,
  });

  final String? id;
  final String? editionId;
  final ExternalIds ids;
  final String title;
  final String? subtitle;
  final List<String> authors;
  final String? description;
  final String? coverUrl;
  final String? publisher;
  final String? publishedDate;
  final int? pageCount;
  final List<String> categories;
  final String? language;

  bool get isStored => id != null && editionId != null;

  String get key => id ?? ids.catalogKey ?? 'title:$title';

  String get authorLine => authors.isEmpty ? 'Unknown author' : authors.join(', ');

  int? get publishedYear {
    final match = RegExp(r'^(\d{4})').firstMatch(publishedDate ?? '');
    return match == null ? null : int.parse(match.group(1)!);
  }

  Book stored({required String id, required String editionId}) => Book(
    id: id,
    editionId: editionId,
    ids: ids,
    title: title,
    subtitle: subtitle,
    authors: authors,
    description: description,
    coverUrl: coverUrl,
    publisher: publisher,
    publishedDate: publishedDate,
    pageCount: pageCount,
    categories: categories,
    language: language,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'edition_id': editionId,
    ...ids.toJson(),
    'title': title,
    'subtitle': subtitle,
    'authors': authors,
    'description': description,
    'cover_url': coverUrl,
    'publisher': publisher,
    'published_date': publishedDate,
    'page_count': pageCount,
    'categories': categories,
    'language': language,
  };

  factory Book.fromJson(Map<String, dynamic> json) => Book(
    id: json['id'] as String?,
    editionId: json['edition_id'] as String?,
    ids: ExternalIds.fromJson(json),
    title: json['title'] as String,
    subtitle: json['subtitle'] as String?,
    authors: _strings(json['authors']),
    description: json['description'] as String?,
    coverUrl: json['cover_url'] as String?,
    publisher: json['publisher'] as String?,
    publishedDate: json['published_date'] as String?,
    pageCount: positiveOrNull(json['page_count']),
    categories: _strings(json['categories']),
    language: json['language'] as String?,
  );

  @override
  List<Object?> get props => [id, editionId, ids, title, authors, pageCount, coverUrl];
}

List<String> _strings(Object? value) => value is List ? value.whereType<String>().toList(growable: false) : const [];

int? positiveOrNull(Object? value) {
  final n = value is num ? value.toInt() : int.tryParse('$value');
  return n != null && n > 0 ? n : null;
}
