enum SearchMode {
  any('All'),
  title('Title'),
  author('Author'),
  isbn('ISBN');

  const SearchMode(this.label);
  final String label;
}

/// A user's search, normalized once. ISBN-looking input is always searched as ISBN.
class CatalogQuery {
  const CatalogQuery._(this.text, this.mode);

  factory CatalogQuery.parse(String raw, {SearchMode mode = SearchMode.any}) {
    final text = raw.trim();
    final compact = text.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    final looksLikeIsbn = RegExp(r'^(\d{9}[\dX]|\d{13})$').hasMatch(compact);
    if (looksLikeIsbn && (mode == SearchMode.any || mode == SearchMode.isbn)) {
      return CatalogQuery._(compact, SearchMode.isbn);
    }
    return CatalogQuery._(text, mode);
  }

  final String text;
  final SearchMode mode;

  bool get isSearchable => text.length >= 2;

  String get googleQuery => switch (mode) {
        SearchMode.any => text,
        SearchMode.title => 'intitle:$text',
        SearchMode.author => 'inauthor:$text',
        SearchMode.isbn => 'isbn:$text',
      };

  /// Query parameters for Open Library's `/search.json`.
  Map<String, String> get openLibraryParams => switch (mode) {
        SearchMode.any => {'q': text},
        SearchMode.title => {'title': text},
        SearchMode.author => {'author': text},
        SearchMode.isbn => {'isbn': text},
      };
}
