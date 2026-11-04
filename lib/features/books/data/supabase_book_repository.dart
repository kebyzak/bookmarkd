import 'package:bookmarkd/core/network/row_mappers.dart';
import 'package:bookmarkd/core/network/supabase_guard.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/books/domain/book_stats.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBookRepository implements BookRepository {
  SupabaseBookRepository(this._client);

  final SupabaseClient _client;

  static const _select = '*, editions:book_editions!book_editions_book_id_fkey(*)';

  @override
  Future<Book> getStoredBook(String bookId) => guardSupabase(() async {
    final row = await _oneEdition(_client.from('books').select(_select).eq('id', bookId)).single();
    return _fromRow(row);
  });

  @override
  Future<Book?> findStored(ExternalIds ids) => guardSupabase(() async {
    final filters = [
      if (ids.googleBooksId != null) 'google_books_id.eq.${ids.googleBooksId}',
      if (ids.openLibraryId != null) 'open_library_id.eq.${ids.openLibraryId}',
      if (ids.isbn13 != null) 'isbn_13.eq.${ids.isbn13}',
    ];
    if (filters.isEmpty) return null;
    final edition = await _client
        .from('book_editions')
        .select('*, work:books!book_editions_book_id_fkey(*)')
        .or(filters.join(','))
        .limit(1)
        .maybeSingle();
    if (edition != null) return bookFromRows((edition['work'] as Map).cast<String, dynamic>(), edition);
    if (ids.openLibraryId == null) return null;
    final work = await _oneEdition(_client.from('books').select(_select).eq('open_library_work_id', ids.openLibraryId!))
        .maybeSingle();
    return work == null ? null : _fromRow(work);
  });

  @override
  Future<Book> save(Book book) => guardSupabase(() async {
    if (book.isStored) return book;
    final res = await _client.functions.invoke(
      'save-book',
      body: {'google_books_id': book.ids.googleBooksId, 'open_library_id': book.ids.openLibraryId},
    );
    final ids = res.data as Map;
    return book.stored(id: ids['book_id'] as String, editionId: ids['edition_id'] as String);
  });

  @override
  Future<BookStats> stats(String bookId) => guardSupabase(() async {
    final rows = await _client.rpc('get_book_stats', params: {'p_book_id': bookId}) as List;
    if (rows.isEmpty) return BookStats.empty;
    final r = rows.first as Map;
    return BookStats(
      averageRating: (r['average_rating'] as num?)?.toDouble(),
      ratingCount: (r['rating_count'] as num).toInt(),
      readerCount: (r['reader_count'] as num).toInt(),
    );
  });

  @override
  Future<List<Book>> popular({String? category, int limit = 20}) => guardSupabase(() async {
    final rows = await _client.rpc('get_popular_books', params: {'p_limit': limit, 'p_category': category}) as List;
    return _hydrate(rows.map((r) => (r as Map)['book_id'] as String).toList());
  });

  @override
  Future<List<Book>> trending({int limit = 20}) => guardSupabase(() async {
    final rows = await _client.rpc('get_trending_books', params: {'p_days': 7, 'p_limit': limit}) as List;
    return _hydrate(rows.map((r) => (r as Map)['book_id'] as String).toList());
  });

  Future<List<Book>> _hydrate(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _oneEdition(_client.from('books').select(_select).inFilter('id', ids));
    final byId = {for (final r in rows) r['id'] as String: _fromRow(r)};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  PostgrestTransformBuilder<PostgrestList> _oneEdition(PostgrestFilterBuilder<PostgrestList> query) =>
      query.order('created_at', ascending: true, referencedTable: 'editions').limit(1, referencedTable: 'editions');

  Book _fromRow(Map<String, dynamic> row) {
    final editions = (row['editions'] as List? ?? const []).cast<Map<String, dynamic>>();
    return bookFromRows(row, editions.isEmpty ? null : editions.first);
  }
}
