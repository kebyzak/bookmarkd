import '../../library/domain/library_entry.dart';
import '../../library/domain/reading_status.dart';

class ReadingStats {
  const ReadingStats({
    required this.finishedThisYear,
    required this.totalFinished,
    required this.pagesRead,
    required this.booksWithPageCount,
    required this.averageRating,
    required this.goal,
  });

  factory ReadingStats.compute(Iterable<LibraryEntry> entries, {required DateTime now, required int? goal}) {
    final finished = entries.where((e) => e.status == ReadingStatus.finished).toList();
    final withPages = finished.where((e) => e.book.pageCount != null).toList();
    final ratings = entries.map((e) => e.rating).nonNulls.toList();
    return ReadingStats(
      finishedThisYear: finished.where((e) => e.finishedAt?.year == now.year).length,
      totalFinished: finished.length,
      pagesRead: withPages.fold(0, (sum, e) => sum + e.book.pageCount!),
      booksWithPageCount: withPages.length,
      averageRating: ratings.isEmpty ? null : ratings.fold<double>(0, (s, r) => s + r.stars) / ratings.length,
      goal: goal,
    );
  }

  final int finishedThisYear;
  final int totalFinished;

  /// Sum of page counts of finished books whose page count is known.
  final int pagesRead;
  final int booksWithPageCount;
  final double? averageRating;
  final int? goal;

  double? get goalProgress => goal == null ? null : (finishedThisYear / goal!).clamp(0, 1);
}
