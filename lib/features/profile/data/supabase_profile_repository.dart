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
}
