import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_guard.dart';
import '../../../core/repositories.dart';
import '../../library/domain/rating.dart';
import '../../profile/domain/profile.dart';
import '../domain/review.dart';

class SupabaseReviewRepository implements ReviewRepository {
  SupabaseReviewRepository(this._client);

  final SupabaseClient _client;

  static const _select = '*, author:profiles(*), book:books(title, cover_url)';

  String get _me => _client.auth.currentUser!.id;

  @override
  Future<List<Review>> forBook(String bookId, {int limit = 20, int offset = 0}) => guardSupabase(() async {
        final rows = await _client
            .from('reviews')
            .select(_select)
            .eq('book_id', bookId)
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);
        return _withRatings(rows);
      });

  @override
  Future<List<Review>> byUser(String userId) => guardSupabase(() async {
        final rows =
            await _client.from('reviews').select(_select).eq('user_id', userId).order('created_at', ascending: false);
        return _withRatings(rows);
      });

  @override
  Future<Review?> mine(String bookId) => guardSupabase(() async {
        final row = await _client.from('reviews').select(_select).eq('book_id', bookId).eq('user_id', _me).maybeSingle();
        return row == null ? null : (await _withRatings([row])).first;
      });

  @override
  Future<Review> upsert({required String bookId, required String body, required bool containsSpoilers}) =>
      guardSupabase(() async {
        final row = await _client
            .from('reviews')
            .upsert(
              {'user_id': _me, 'book_id': bookId, 'body': body.trim(), 'contains_spoilers': containsSpoilers},
              onConflict: 'user_id,book_id',
            )
            .select(_select)
            .single();
        return (await _withRatings([row])).first;
      });

  @override
  Future<void> delete(String reviewId) => guardSupabase(() => _client.from('reviews').delete().eq('id', reviewId));

  /// Ratings live on user_books; fetch them for the reviewers in one query.
  Future<List<Review>> _withRatings(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return const [];
    final pairs = rows.map((r) => (r['user_id'] as String, r['book_id'] as String)).toList();
    final ratingRows = await _client
        .from('user_books')
        .select('user_id, book_id, rating')
        .inFilter('user_id', pairs.map((p) => p.$1).toSet().toList())
        .inFilter('book_id', pairs.map((p) => p.$2).toSet().toList());
    final ratings = {for (final r in ratingRows) '${r['user_id']}|${r['book_id']}': Rating.tryParse(r['rating'])};
    return rows.map((r) {
      final book = (r['book'] as Map?)?.cast<String, dynamic>();
      return Review(
        id: r['id'] as String,
        author: Profile.fromJson((r['author'] as Map).cast<String, dynamic>()),
        bookId: r['book_id'] as String,
        body: r['body'] as String,
        containsSpoilers: r['contains_spoilers'] as bool? ?? false,
        createdAt: DateTime.parse(r['created_at'] as String),
        rating: ratings['${r['user_id']}|${r['book_id']}'],
        bookTitle: book?['title'] as String?,
        coverUrl: book?['cover_url'] as String?,
      );
    }).toList();
  }
}
