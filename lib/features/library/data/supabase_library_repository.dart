import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/row_mappers.dart';
import '../../../core/network/supabase_guard.dart';
import '../../../core/repositories.dart';
import '../../books/domain/book.dart';
import '../../reading/domain/progress_update.dart';
import '../../reading/domain/reading_session.dart';
import '../domain/library_entry.dart';
import '../domain/reading_status.dart';
import '../domain/status_transition.dart';

class SupabaseLibraryRepository implements LibraryRepository {
  SupabaseLibraryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<LibraryEntry>> getLibrary(String userId) => guardSupabase(() async {
        final rows = await _client
            .from('user_books')
            .select(userBookSelect)
            .eq('user_id', userId)
            .order('created_at', ascending: false);
        return rows.map(entryFromRow).toList();
      });

  /// Upserts on (user_id, book_id): re-adding a work updates the one entry.
  @override
  Future<LibraryEntry> add(Book storedBook, ReadingStatus status) => guardSupabase(() async {
        final userId = _client.auth.currentUser!.id;
        final blank = LibraryEntry(
          id: '',
          userId: userId,
          book: storedBook,
          status: ReadingStatus.wantToRead,
          addedAt: DateTime.now(),
        );
        final initial = transitionStatus(blank, status, today: DateTime.now());
        final row = await _client
            .from('user_books')
            .upsert(
              {
                'user_id': userId,
                'book_id': storedBook.id,
                'edition_id': storedBook.editionId,
                ...entryToUpdateRow(initial),
              },
              onConflict: 'user_id,book_id',
            )
            .select(userBookSelect)
            .single();
        return entryFromRow(row);
      });

  @override
  Future<LibraryEntry> update(LibraryEntry entry) => guardSupabase(() async {
        final row = await _client
            .from('user_books')
            .update(entryToUpdateRow(entry))
            .eq('id', entry.id)
            .select(userBookSelect)
            .single();
        return entryFromRow(row);
      });

  @override
  Future<void> remove(String entryId) => guardSupabase(() => _client.from('user_books').delete().eq('id', entryId));

  @override
  Future<LibraryEntry> logProgress(String entryId, ProgressUpdate update) => guardSupabase(() async {
        await _client.rpc('log_reading_progress', params: {
          'p_user_book_id': entryId,
          'p_current_page': update.page,
          'p_progress_percent': update.percent,
        });
        final row = await _client.from('user_books').select(userBookSelect).eq('id', entryId).single();
        return entryFromRow(row);
      });

  @override
  Future<List<ReadingSession>> sessions(String entryId) => guardSupabase(() async {
        final rows = await _client
            .from('reading_sessions')
            .select()
            .eq('user_book_id', entryId)
            .order('created_at', ascending: false)
            .limit(50);
        return rows.map(ReadingSession.fromJson).toList();
      });
}
