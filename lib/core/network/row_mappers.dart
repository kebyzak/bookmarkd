import '../../features/books/domain/book.dart';
import '../../features/library/domain/library_entry.dart';
import '../../features/library/domain/rating.dart';
import '../../features/library/domain/reading_status.dart';

/// Shared mappers from Supabase rows to domain models.

/// Combines a `books` row with one of its `book_editions` rows.
Book bookFromRows(Map<String, dynamic> work, Map<String, dynamic>? edition) => Book(
  id: work['id'] as String,
  editionId: edition?['id'] as String?,
  ids: edition == null ? const ExternalIds() : ExternalIds.fromJson(edition),
  title: work['title'] as String,
  subtitle: work['subtitle'] as String?,
  authors: (work['authors'] as List? ?? const []).cast<String>(),
  description: work['description'] as String?,
  coverUrl: (edition?['cover_url'] ?? work['cover_url']) as String?,
  publisher: edition?['publisher'] as String?,
  publishedDate: (edition?['published_date'] ?? work['first_published']) as String?,
  pageCount: positiveOrNull(edition?['page_count']),
  categories: (work['categories'] as List? ?? const []).cast<String>(),
  language: edition?['language'] as String?,
);

// Constraint names pick the FK: user_books also has a composite (edition_id, book_id) FK,
// which makes a bare book_editions embed ambiguous (PostgREST PGRST201).
const userBookSelect = '*, book:books!user_books_book_id_fkey(*), edition:book_editions!user_books_edition_id_fkey(*)';

LibraryEntry entryFromRow(Map<String, dynamic> row) => LibraryEntry(
  id: row['id'] as String,
  userId: row['user_id'] as String,
  book: bookFromRows((row['book'] as Map).cast<String, dynamic>(), (row['edition'] as Map?)?.cast<String, dynamic>()),
  status: ReadingStatus.fromDb(row['status'] as String),
  currentPage: row['current_page'] as int?,
  progressPercent: row['progress_percent'] as int?,
  rating: Rating.tryParse(row['rating']),
  isFavorite: row['is_favorite'] as bool? ?? false,
  startedAt: _date(row['started_at']),
  finishedAt: _date(row['finished_at']),
  addedAt: DateTime.parse(row['created_at'] as String),
);

Map<String, dynamic> entryToUpdateRow(LibraryEntry e) => {
  'status': e.status.dbValue,
  'current_page': e.currentPage,
  'progress_percent': e.progressPercent,
  'rating': e.rating?.halfStars,
  'is_favorite': e.isFavorite,
  'started_at': _dateString(e.startedAt),
  'finished_at': _dateString(e.finishedAt),
};

DateTime? _date(Object? v) => v is String ? DateTime.parse(v) : null;

String? _dateString(DateTime? d) =>
    d == null ? null : '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

String _two(int n) => n.toString().padLeft(2, '0');
