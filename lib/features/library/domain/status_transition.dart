import 'library_entry.dart';
import 'reading_status.dart';

LibraryEntry transitionStatus(LibraryEntry entry, ReadingStatus to, {required DateTime today}) {
  if (entry.status == to) return entry;
  final date = DateTime(today.year, today.month, today.day);
  return switch (to) {
    ReadingStatus.wantToRead => entry.copyWith(
      status: to,
      startedAt: () => null,
      finishedAt: () => null,
      currentPage: () => null,
      progressPercent: () => null,
    ),
    ReadingStatus.reading => entry.copyWith(
      status: to,
      startedAt: () => entry.startedAt ?? date,
      finishedAt: () => null,
    ),
    ReadingStatus.finished => entry.copyWith(
      status: to,
      startedAt: () => entry.startedAt ?? date,
      finishedAt: () => entry.finishedAt ?? date,
      currentPage: () => entry.book.pageCount ?? entry.currentPage,
      progressPercent: () => 100,
    ),
    ReadingStatus.dnf => entry.copyWith(status: to, finishedAt: () => null),
  };
}
