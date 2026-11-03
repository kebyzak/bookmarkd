import 'dart:typed_data';

import 'package:bookmarkd/core/network/supabase_guard.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/utils/wait_all.dart';
import 'package:bookmarkd/features/profile/domain/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProfileRepository implements ProfileRepository, SocialRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  String get _me => _client.auth.currentUser!.id;

  @override
  Future<Profile> getProfile(String userId) => guardSupabase(() async {
    final row = await _client.from('profiles').select().eq('id', userId).single();
    return Profile.fromJson(row);
  });

  @override
  Future<Profile> updateProfile(Profile profile) => guardSupabase(() async {
    final row = await _client.from('profiles').update(profile.toUpdateJson()).eq('id', profile.id).select().single();
    return Profile.fromJson(row);
  });

  @override
  Future<bool> isUsernameAvailable(String username, {required String exceptUserId}) => guardSupabase(() async {
    final row = await _client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .neq('id', exceptUserId)
        .maybeSingle();
    return row == null;
  });

  @override
  Future<String> uploadAvatar(String userId, Uint8List bytes, {required String extension}) => guardSupabase(() async {
    final path = '$userId/avatar';
    await _client.storage
        .from('avatars')
        .uploadBinary(path, bytes, fileOptions: FileOptions(upsert: true, contentType: 'image/$extension'));
    return '${_client.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
  });

  @override
  Future<List<Profile>> searchProfiles(String query) => guardSupabase(() async {
    final q = query.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (q.isEmpty) return const <Profile>[];
    final rows = await _client.from('profiles').select().ilike('username', '%$q%').eq('onboarded', true).limit(20);
    return rows.map(Profile.fromJson).toList();
  });

  @override
  Future<FollowCounts> followCounts(String userId) => guardSupabase(() async {
    final followers = _client.from('follows').count().eq('followee_id', userId);
    final following = _client.from('follows').count().eq('follower_id', userId);
    await waitAll([followers, following]);
    return FollowCounts(followers: await followers, following: await following);
  });

  @override
  Future<bool> isFollowing(String otherUserId) => guardSupabase(() async {
    final row = await _client
        .from('follows')
        .select('followee_id')
        .eq('follower_id', _me)
        .eq('followee_id', otherUserId)
        .maybeSingle();
    return row != null;
  });

  @override
  Future<void> follow(String otherUserId) => guardSupabase(
    () => _client.from('follows').upsert({'follower_id': _me, 'followee_id': otherUserId}, ignoreDuplicates: true),
  );

  @override
  Future<void> unfollow(String otherUserId) =>
      guardSupabase(() => _client.from('follows').delete().eq('follower_id', _me).eq('followee_id', otherUserId));

  static const _listLimit = 200;

  @override
  Future<List<ReaderLink>> followers(String userId) => _links(
    _client
        .from('follows')
        .select('created_at, profile:profiles!follows_follower_id_fkey(*)')
        .eq('followee_id', userId)
        .order('created_at', ascending: false)
        .limit(_listLimit),
  );

  @override
  Future<List<ReaderLink>> following(String userId) => _links(
    _client
        .from('follows')
        .select('created_at, profile:profiles!follows_followee_id_fkey(*)')
        .eq('follower_id', userId)
        .order('created_at', ascending: false)
        .limit(_listLimit),
  );

  @override
  Future<List<ReaderLink>> followNotifications() => _links(
    _client
        .from('notifications')
        .select('created_at, read_at, profile:profiles!notifications_actor_id_fkey(*)')
        .eq('user_id', _me)
        .eq('type', 'follow')
        .order('created_at', ascending: false)
        .limit(50),
  );

  @override
  Future<int> unreadNotificationCount() =>
      guardSupabase(() => _client.from('notifications').count().eq('user_id', _me).isFilter('read_at', null));

  @override
  Future<void> markNotificationsRead() => guardSupabase(
    () => _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', _me)
        .isFilter('read_at', null),
  );

  Future<List<ReaderLink>> _links(Future<List<Map<String, dynamic>>> query) => guardSupabase(() async {
    final rows = await query;
    final profiles = [for (final r in rows) Profile.fromJson((r['profile'] as Map).cast<String, dynamic>())];
    final followed = profiles.isEmpty
        ? const <String>{}
        : (await _client.from('follows').select('followee_id').eq('follower_id', _me).inFilter('followee_id', [
            for (final p in profiles) p.id,
          ])).map((r) => r['followee_id'] as String).toSet();
    return [
      for (final (i, r) in rows.indexed)
        ReaderLink(
          profile: profiles[i],
          following: followed.contains(profiles[i].id),
          at: DateTime.parse(r['created_at'] as String),
          unread: r.containsKey('read_at') && r['read_at'] == null,
        ),
    ];
  });
}
