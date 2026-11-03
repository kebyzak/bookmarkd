import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/library/domain/library_entry.dart';

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
