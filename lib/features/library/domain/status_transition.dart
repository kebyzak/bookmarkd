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
    ReadingStatus.finished => finishOn(entry, ReadOn(entry.finishedAt ?? date)),
    ReadingStatus.dnf => entry.copyWith(status: to, finishedAt: () => null),
  };
}

sealed class FinishDate {
  const FinishDate();
}

final class ReadOn extends FinishDate {
  const ReadOn(this.day);

  final DateTime day;
}

final class ReadSometimeAgo extends FinishDate {
  const ReadSometimeAgo();
}

LibraryEntry finishOn(LibraryEntry entry, FinishDate when) {
  final day = switch (when) {
    ReadOn(:final day) => DateTime(day.year, day.month, day.day),
    ReadSometimeAgo() => null,
  };
  final started = entry.startedAt;
  return entry.copyWith(
    status: ReadingStatus.finished,
    startedAt: () => day != null && (started == null || started.isAfter(day)) ? day : started,
    finishedAt: () => day,
    currentPage: () => entry.book.pageCount ?? entry.currentPage,
    progressPercent: () => 100,
  );
}
