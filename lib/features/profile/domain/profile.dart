import 'package:equatable/equatable.dart';

final usernamePattern = RegExp(r'^[a-z0-9_]{3,24}$');

String? validateUsername(String? value) {
  final v = value?.trim() ?? '';
  if (v.length < 3) return 'At least 3 characters';
  if (v.length > 24) return 'At most 24 characters';
  if (!usernamePattern.hasMatch(v)) return 'Lowercase letters, numbers and _ only';
  return null;
}

class Profile extends Equatable {
  const Profile({
    required this.id,
    this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
    this.readingGoal,
    this.isPrivate = false,
    this.onboarded = false,
  });

  final String id;
  final String? username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final int? readingGoal;
  final bool isPrivate;
  final bool onboarded;

  String get name => (displayName?.isNotEmpty ?? false) ? displayName! : (username ?? 'Reader');

  String get handle => username == null ? '' : '@$username';

  Profile copyWith({
    String? username,
    String? Function()? displayName,
    String? Function()? bio,
    String? Function()? avatarUrl,
    int? Function()? readingGoal,
    bool? isPrivate,
    bool? onboarded,
  }) => Profile(
    id: id,
    username: username ?? this.username,
    displayName: displayName != null ? displayName() : this.displayName,
    bio: bio != null ? bio() : this.bio,
    avatarUrl: avatarUrl != null ? avatarUrl() : this.avatarUrl,
    readingGoal: readingGoal != null ? readingGoal() : this.readingGoal,
    isPrivate: isPrivate ?? this.isPrivate,
    onboarded: onboarded ?? this.onboarded,
  );

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    username: json['username'] as String?,
    displayName: json['display_name'] as String?,
    bio: json['bio'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    readingGoal: json['reading_goal'] as int?,
    isPrivate: json['is_private'] as bool? ?? false,
    onboarded: json['onboarded'] as bool? ?? false,
  );

  Map<String, dynamic> toUpdateJson() => {
    'username': username,
    'display_name': displayName,
    'bio': bio,
    'avatar_url': avatarUrl,
    'reading_goal': readingGoal,
    'is_private': isPrivate,
    'onboarded': onboarded,
  };

  @override
  List<Object?> get props => [id, username, displayName, bio, avatarUrl, readingGoal, isPrivate, onboarded];
}

class FollowCounts extends Equatable {
  const FollowCounts({required this.followers, required this.following});

  final int followers;
  final int following;

  @override
  List<Object?> get props => [followers, following];
}
