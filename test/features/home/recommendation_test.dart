import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/home/domain/recommendation.dart';
import 'package:bookmarkd/features/library/domain/library_entry.dart';
import 'package:bookmarkd/features/library/domain/reading_status.dart';
import 'package:flutter_test/flutter_test.dart';

Book book(String id, List<String> categories) =>
    Book(id: id, editionId: 'e$id', ids: const ExternalIds(), title: id, authors: const [], categories: categories);

LibraryEntry onShelf(Book b) =>
    LibraryEntry(id: 'x${b.id}', userId: 'u', book: b, status: ReadingStatus.finished, addedAt: DateTime(2026));

void main() {
  test('top genre is the most common category on the shelf', () {
    final shelf = [
      onShelf(book('a', ['Fantasy'])),
      onShelf(book('b', ['Fantasy', 'Classics'])),
      onShelf(book('c', ['Classics'])),
      onShelf(book('d', ['Fantasy'])),
    ];
    expect(topGenre(shelf), 'Fantasy');
    expect(topGenre(const []), isNull);
  });

  test('recommendations exclude books already on the shelf', () {
    final owned = book('a', ['Fantasy']);
    final result = excludeOwned(
      [
        owned,
        book('b', ['Fantasy']),
      ],
      [onShelf(owned)],
    );
    expect(result.map((b) => b.id), ['b']);
  });
}
