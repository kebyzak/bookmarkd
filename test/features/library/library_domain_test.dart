import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/library/domain/library_entry.dart';
import 'package:bookmarkd/features/library/domain/library_query.dart';
import 'package:bookmarkd/features/library/domain/rating.dart';
import 'package:bookmarkd/features/library/domain/reading_status.dart';
import 'package:bookmarkd/features/reading/domain/progress_update.dart';
import 'package:bookmarkd/features/statistics/domain/reading_stats.dart';
import 'package:flutter_test/flutter_test.dart';

LibraryEntry entry(
  String title, {
  ReadingStatus status = ReadingStatus.wantToRead,
  int? halfStars,
  int? pages,
  String? year,
  DateTime? added,
  DateTime? finished,
  String author = 'Someone',
}) =>
    LibraryEntry(
      id: 'e-$title',
      userId: 'u1',
      book: Book(
        id: 'b-$title',
        editionId: 'ed-$title',
        ids: const ExternalIds(),
        title: title,
        authors: [author],
        pageCount: pages,
        publishedDate: year,
      ),
      status: status,
      rating: halfStars == null ? null : Rating.fromHalfStars(halfStars),
      addedAt: added ?? DateTime(2026, 1, 1),
      finishedAt: finished,
    );

void main() {
  group('Rating', () {
    test('accepts half stars 1..10 only', () {
      expect(Rating.fromHalfStars(7).stars, 3.5);
      expect(() => Rating.fromHalfStars(0), throwsArgumentError);
      expect(() => Rating.fromHalfStars(11), throwsArgumentError);
      expect(Rating.fromStars(4.5).halfStars, 9);
    });
  });

  group('ReadingStatus', () {
    test('round-trips database values', () {
      for (final s in ReadingStatus.values) {
        expect(ReadingStatus.fromDb(s.dbValue), s);
      }
    });
  });

  group('LibraryQuery', () {
    final books = [
      entry('Beta', status: ReadingStatus.finished, halfStars: 6, year: '1990', added: DateTime(2026, 3)),
      entry('alpha', status: ReadingStatus.reading, year: '2010', added: DateTime(2026, 1)),
      entry('Gamma', status: ReadingStatus.finished, halfStars: 10, added: DateTime(2026, 2), author: 'Le Guin'),
    ];

    test('filters by status', () {
      final result = const LibraryQuery(status: ReadingStatus.finished).apply(books);
      expect(result.map((e) => e.book.title), ['Beta', 'Gamma']);
    });

    test('searches title and author case-insensitively', () {
      expect(const LibraryQuery(search: 'guin').apply(books).single.book.title, 'Gamma');
      expect(const LibraryQuery(search: 'ALP').apply(books).single.book.title, 'alpha');
    });

    test('sorts by each order with unknown values last', () {
      List<String> titles(LibrarySort s) => LibraryQuery(sort: s).apply(books).map((e) => e.book.title).toList();
      expect(titles(LibrarySort.dateAdded), ['Beta', 'Gamma', 'alpha']);
      expect(titles(LibrarySort.rating), ['Gamma', 'Beta', 'alpha']);
      expect(titles(LibrarySort.title), ['alpha', 'Beta', 'Gamma']);
      expect(titles(LibrarySort.publicationYear), ['alpha', 'Beta', 'Gamma']);
    });

    test('counts every status', () {
      final counts = statusCounts(books);
      expect(counts[ReadingStatus.finished], 2);
      expect(counts[ReadingStatus.reading], 1);
      expect(counts[ReadingStatus.dnf], 0);
    });
  });

  group('ProgressUpdate', () {
    test('derives percent from page when page count is known', () {
      final u = ProgressUpdate.page(150, pageCount: 300);
      expect(u.percent, 50);
      expect(u.isComplete, isFalse);
    });

    test('reaching the last page is complete', () {
      expect(ProgressUpdate.page(300, pageCount: 300).isComplete, isTrue);
      expect(ProgressUpdate.percent(100).isComplete, isTrue);
    });

    test('rejects out-of-range input', () {
      expect(ProgressUpdate.validatePage(301, pageCount: 300), isNotNull);
      expect(ProgressUpdate.validatePage(-1, pageCount: 300), isNotNull);
      expect(ProgressUpdate.validatePage(12, pageCount: 300), isNull);
      expect(() => ProgressUpdate.percent(101), throwsArgumentError);
    });
  });

  group('ReadingStats', () {
    test('computes yearly and lifetime numbers from library entries', () {
      final stats = ReadingStats.compute(
        [
          entry('A', status: ReadingStatus.finished, pages: 200, halfStars: 8, finished: DateTime(2026, 5)),
          entry('B', status: ReadingStatus.finished, halfStars: 6, finished: DateTime(2025, 5)),
          entry('C', status: ReadingStatus.reading, pages: 999),
        ],
        now: DateTime(2026, 11, 2),
        goal: 4,
      );
      expect(stats.finishedThisYear, 1);
      expect(stats.totalFinished, 2);
      expect(stats.pagesRead, 200);
      expect(stats.booksWithPageCount, 1);
      expect(stats.averageRating, 3.5);
      expect(stats.goalProgress, 0.25);
    });

    test('has no average or goal progress when there is no data', () {
      final stats = ReadingStats.compute(const [], now: DateTime(2026), goal: null);
      expect(stats.averageRating, isNull);
      expect(stats.goalProgress, isNull);
    });
  });
}
