import 'package:bookmarkd/features/books/data/catalog_parsers.dart';
import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/books/domain/catalog_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseGoogleVolume', () {
    test('normalizes a full volume', () {
      final book = parseGoogleVolume({
        'id': 'abc123',
        'volumeInfo': {
          'title': 'Dune',
          'subtitle': 'Deluxe Edition',
          'authors': ['Frank Herbert'],
          'publisher': 'Ace',
          'publishedDate': '2019-10-01',
          'description': 'Spice.',
          'industryIdentifiers': [
            {'type': 'ISBN_10', 'identifier': '0593099324'},
            {'type': 'ISBN_13', 'identifier': '9780593099322'},
          ],
          'pageCount': 896,
          'categories': ['Fiction / Science Fiction / General'],
          'language': 'en',
          'imageLinks': {
            'thumbnail': 'http://books.google.com/books/content?id=abc123&printsec=frontcover&img=1&zoom=1&edge=curl&source=gbs_api',
          },
        },
      });

      expect(book.key, 'gb:abc123');
      expect(book.title, 'Dune');
      expect(book.subtitle, 'Deluxe Edition');
      expect(book.authors, ['Frank Herbert']);
      expect(book.ids.isbn10, '0593099324');
      expect(book.ids.isbn13, '9780593099322');
      expect(book.pageCount, 896);
      expect(book.publishedYear, 2019);
      expect(book.categories, ['Science Fiction']);
      expect(book.coverUrl, startsWith('https://'));
      expect(book.coverUrl, isNot(contains('edge=curl')));
    });

    test('tolerates missing metadata', () {
      final book = parseGoogleVolume({
        'id': 'x',
        'volumeInfo': {'title': 'Untitled thing', 'pageCount': 0},
      });
      expect(book.authors, isEmpty);
      expect(book.coverUrl, isNull);
      expect(book.pageCount, isNull);
      expect(book.publishedYear, isNull);
    });
  });

  group('parseOpenLibraryDoc', () {
    test('normalizes a search doc and builds a cover url', () {
      final book = parseOpenLibraryDoc({
        'key': '/works/OL45804W',
        'title': 'Fantastic Mr Fox',
        'author_name': ['Roald Dahl'],
        'first_publish_year': 1970,
        'isbn': ['0140328726', '9780140328721'],
        'number_of_pages_median': 96,
        'cover_i': 6498519,
        'publisher': ['Puffin'],
        'subject': ['Foxes'],
        'language': ['eng'],
      });
      expect(book.key, 'ol:OL45804W');
      expect(book.ids.isbn13, '9780140328721');
      expect(book.ids.isbn10, '0140328726');
      expect(book.publishedYear, 1970);
      expect(book.pageCount, 96);
      expect(book.coverUrl, 'https://covers.openlibrary.org/b/id/6498519-L.jpg');
    });
  });

  group('CatalogQuery', () {
    test('detects ISBNs written with hyphens', () {
      final q = CatalogQuery.parse('978-0-14-032872-1');
      expect(q.mode, SearchMode.isbn);
      expect(q.googleQuery, 'isbn:9780140328721');
    });

    test('builds field-scoped google queries', () {
      expect(CatalogQuery.parse('herbert', mode: SearchMode.author).googleQuery, 'inauthor:herbert');
      expect(CatalogQuery.parse('dune', mode: SearchMode.title).googleQuery, 'intitle:dune');
      expect(CatalogQuery.parse('dune').googleQuery, 'dune');
    });

    test('blank input is not searchable', () {
      expect(CatalogQuery.parse('   ').isSearchable, isFalse);
    });
  });

  group('dedupeBooks', () {
    Book book(String gid, {String? isbn13}) => Book(
      ids: ExternalIds(googleBooksId: gid, isbn13: isbn13),
      title: 'T$gid',
      authors: const [],
    );

    test('drops repeated external ids and repeated ISBN-13s, keeping the first', () {
      final result = dedupeBooks([book('a', isbn13: '1'), book('a'), book('b', isbn13: '1'), book('c', isbn13: '2')]);
      expect(result.map((b) => b.ids.googleBooksId), ['a', 'c']);
    });
  });
}
