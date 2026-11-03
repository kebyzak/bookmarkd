enum SearchMode {
  any('All'),
  title('Title'),
  author('Author'),
  isbn('ISBN');

  const SearchMode(this.label);

  final String label;
}

class CatalogQuery {
  const CatalogQuery._(this.text, this.mode, {this.author});

  factory CatalogQuery.parse(String raw, {SearchMode mode = SearchMode.any, String? author}) {
    final text = raw.trim();
    if (author != null) {
      return CatalogQuery._(text.length < 2 ? '' : text, SearchMode.title, author: author.replaceAll('"', ''));
    }
    final compact = text.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    final looksLikeIsbn = RegExp(r'^(\d{9}[\dX]|\d{13})$').hasMatch(compact);
    if (looksLikeIsbn && (mode == SearchMode.any || mode == SearchMode.isbn)) {
      return CatalogQuery._(compact, SearchMode.isbn);
    }
    return CatalogQuery._(text, mode);
  }

  final String text;
  final SearchMode mode;
  final String? author;

  bool get isSearchable => author != null || text.length >= 2;

  String get googleQuery {
    if (author != null) return ['inauthor:"$author"', if (text.isNotEmpty) 'intitle:$text'].join(' ');
    return switch (mode) {
      SearchMode.any => text,
      SearchMode.title => 'intitle:$text',
      SearchMode.author => 'inauthor:$text',
      SearchMode.isbn => 'isbn:$text',
    };
  }

  Map<String, String> get openLibraryParams {
    if (author != null) return {'author': author!, if (text.isNotEmpty) 'title': text};
    return switch (mode) {
      SearchMode.any => {'q': text},
      SearchMode.title => {'title': text},
      SearchMode.author => {'author': text},
      SearchMode.isbn => {'isbn': text},
    };
  }
}

const catalogPageSize = 20;
