import 'package:equatable/equatable.dart';

import 'library_entry.dart';
import 'reading_status.dart';

enum LibrarySort {
  dateAdded('Date added'),
  rating('Rating'),
  title('Title'),
  publicationYear('Publication year');

  const LibrarySort(this.label);
  final String label;
}

/// Filter + sort + search over a library. Pure; the page holds one of these.
class LibraryQuery extends Equatable {
  const LibraryQuery({this.status, this.search = '', this.sort = LibrarySort.dateAdded});

  /// Null means all statuses.
  final ReadingStatus? status;
  final String search;
  final LibrarySort sort;

  LibraryQuery copyWith({ReadingStatus? Function()? status, String? search, LibrarySort? sort}) => LibraryQuery(
        status: status != null ? status() : this.status,
        search: search ?? this.search,
        sort: sort ?? this.sort,
      );

  List<LibraryEntry> apply(Iterable<LibraryEntry> entries) {
    final needle = search.trim().toLowerCase();
    final result = entries.where((e) {
      if (status != null && e.status != status) return false;
      if (needle.isEmpty) return true;
      return e.book.title.toLowerCase().contains(needle) || e.book.authorLine.toLowerCase().contains(needle);
    }).toList();
    result.sort(_comparator);
    return result;
  }

  int _comparator(LibraryEntry a, LibraryEntry b) => switch (sort) {
        LibrarySort.dateAdded => b.addedAt.compareTo(a.addedAt),
        LibrarySort.rating => _descNullsLast(a.rating?.halfStars, b.rating?.halfStars),
        LibrarySort.title => a.book.title.toLowerCase().compareTo(b.book.title.toLowerCase()),
        LibrarySort.publicationYear => _descNullsLast(a.book.publishedYear, b.book.publishedYear),
      };

  @override
  List<Object?> get props => [status, search, sort];
}

int _descNullsLast(int? a, int? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}

Map<ReadingStatus, int> statusCounts(Iterable<LibraryEntry> entries) {
  final counts = {for (final s in ReadingStatus.values) s: 0};
  for (final e in entries) {
    counts[e.status] = counts[e.status]! + 1;
  }
  return counts;
}
