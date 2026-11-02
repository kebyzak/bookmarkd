import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/repositories.dart';
import '../../../core/utils/wait_all.dart';
import '../../../core/widgets/states.dart';
import '../../library/domain/library_entry.dart';
import '../../reviews/domain/review.dart';
import '../domain/profile.dart';

class ProfileState extends Equatable {
  const ProfileState({
    this.status = LoadStatus.loading,
    this.profile,
    this.counts = const FollowCounts(followers: 0, following: 0),
    this.isFollowing = false,
    this.entries = const [],
    this.reviews = const [],
    this.failure,
  });

  final LoadStatus status;
  final Profile? profile;
  final FollowCounts counts;
  final bool isFollowing;

  /// Another reader's library. For the signed-in reader, use LibraryCubit.
  final List<LibraryEntry> entries;
  final List<Review> reviews;
  final AppFailure? failure;

  ProfileState copyWith({
    LoadStatus? status,
    Profile? profile,
    FollowCounts? counts,
    bool? isFollowing,
    List<LibraryEntry>? entries,
    List<Review>? reviews,
    AppFailure? failure,
  }) => ProfileState(
    status: status ?? this.status,
    profile: profile ?? this.profile,
    counts: counts ?? this.counts,
    isFollowing: isFollowing ?? this.isFollowing,
    entries: entries ?? this.entries,
    reviews: reviews ?? this.reviews,
    failure: failure ?? this.failure,
  );

  @override
  List<Object?> get props => [status, profile, counts, isFollowing, entries, reviews, failure];
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required this.userId,
    required this.isSelf,
    required this._profiles,
    required this._social,
    required this._library,
    required this._reviews,
  }) : super(const ProfileState());

  final String userId;
  final bool isSelf;
  final ProfileRepository _profiles;
  final SocialRepository _social;
  final LibraryRepository _library;
  final ReviewRepository _reviews;

  Future<void> load() async {
    try {
      final r = await waitAll([
        _profiles.getProfile(userId),
        _social.followCounts(userId),
        isSelf ? Future.value(false) : _social.isFollowing(userId),
        isSelf ? Future.value(const <LibraryEntry>[]) : _library.getLibrary(userId),
        _reviews.byUser(userId),
      ]);
      if (isClosed) return;
      emit(
        ProfileState(
          status: LoadStatus.success,
          profile: r[0] as Profile,
          counts: r[1] as FollowCounts,
          isFollowing: r[2] as bool,
          entries: r[3] as List<LibraryEntry>,
          reviews: r[4] as List<Review>,
        ),
      );
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, failure: AppFailure.from(e)));
    }
  }

  /// Optimistic; rolls back and rethrows on failure.
  Future<void> toggleFollow() async {
    final before = state;
    final following = !state.isFollowing;
    emit(
      state.copyWith(
        isFollowing: following,
        counts: FollowCounts(
          followers: state.counts.followers + (following ? 1 : -1),
          following: state.counts.following,
        ),
      ),
    );
    try {
      following ? await _social.follow(userId) : await _social.unfollow(userId);
    } catch (e) {
      if (!isClosed) emit(before);
      throw AppFailure.from(e);
    }
  }

  void profileUpdated(Profile profile) => emit(state.copyWith(profile: profile));
}
