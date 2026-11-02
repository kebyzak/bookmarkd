import '../../books/domain/book.dart';
import '../../library/domain/library_entry.dart';

/// MVP heuristic (see docs/ARCHITECTURE.md §7): "popular in your most-read genre".
/// Ties go to the genre seen first.
String? topGenre(Iterable<LibraryEntry> entries) {
  final counts = <String, int>{};
  for (final e in entries) {
    for (final c in e.book.categories) {
      counts.update(c, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  if (counts.isEmpty) return null;
  return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

List<Book> excludeOwned(Iterable<Book> candidates, Iterable<LibraryEntry> entries) {
  final owned = entries.map((e) => e.book.id).toSet();
  return candidates.where((b) => !owned.contains(b.id)).toList();
}
