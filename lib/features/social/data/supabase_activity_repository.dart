import 'package:bookmarkd/core/network/supabase_guard.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/library/domain/rating.dart';
import 'package:bookmarkd/features/profile/domain/profile.dart';
import 'package:bookmarkd/features/social/domain/activity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseActivityRepository implements ActivityRepository {
  SupabaseActivityRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<FeedPage> feed({FeedCursor? before, int limit = 20}) => guardSupabase(() async {
    final rows = await _client.rpc(
      'get_feed',
      params: {'p_before_ts': before?.createdAt.toUtc().toIso8601String(), 'p_before_id': before?.id, 'p_limit': limit},
    ) as List;
    final items = rows.map((r) => _fromRow((r as Map).cast<String, dynamic>())).toList();
    final next = items.length < limit ? null : FeedCursor(items.last.createdAt, items.last.id);
    return FeedPage(items, next);
  });

  @override
  Future<void> like(String activityId) => guardSupabase(
    () => _client.from('activity_likes').upsert({
      'activity_id': activityId,
      'user_id': _client.auth.currentUser!.id,
    }, ignoreDuplicates: true),
  );

  @override
  Future<void> unlike(String activityId) => guardSupabase(
    () => _client
        .from('activity_likes')
        .delete()
        .eq('activity_id', activityId)
        .eq('user_id', _client.auth.currentUser!.id),
  );

  Activity _fromRow(Map<String, dynamic> r) => Activity(
    id: r['id'] as String,
    type: ActivityType.fromDb(r['type'] as String),
    createdAt: DateTime.parse(r['created_at'] as String),
    rating: Rating.tryParse(r['rating']),
    actor: Profile(
      id: r['actor_id'] as String,
      username: r['actor_username'] as String?,
      displayName: r['actor_display_name'] as String?,
      avatarUrl: r['actor_avatar_url'] as String?,
    ),
    book: Book(
      id: r['book_id'] as String,
      ids: const ExternalIds(),
      title: r['book_title'] as String,
      authors: (r['book_authors'] as List? ?? const []).cast<String>(),
      coverUrl: r['cover_url'] as String?,
    ),
    reviewExcerpt: r['review_excerpt'] as String?,
    likeCount: (r['like_count'] as num).toInt(),
    likedByMe: r['liked_by_me'] as bool,
  );
}
