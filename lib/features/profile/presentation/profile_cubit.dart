import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/utils/wait_all.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/library/domain/library_entry.dart';
import 'package:bookmarkd/features/profile/domain/profile.dart';
import 'package:bookmarkd/features/reviews/domain/review.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileState extends Equatable {
  const ProfileState({
    this.status = LoadStatus.loading,
    this.profile,
    this.counts = const FollowCounts(followers: 0, following: 0),
    this.isFollowing = false,
    this.entries = const [],
    this.reviews = const [],
    this.reviewCount = 0,
    this.failure,
  });

  final LoadStatus status;
  final Profile? profile;
  final FollowCounts counts;
  final bool isFollowing;
  final List<LibraryEntry> entries;
  final List<Review> reviews;
  final int reviewCount;
  final AppFailure? failure;

  ProfileState copyWith({
    LoadStatus? status,
    Profile? profile,
    FollowCounts? counts,
    bool? isFollowing,
    List<LibraryEntry>? entries,
    List<Review>? reviews,
    int? reviewCount,
    AppFailure? failure,
  }) => ProfileState(
    status: status ?? this.status,
    profile: profile ?? this.profile,
    counts: counts ?? this.counts,
    isFollowing: isFollowing ?? this.isFollowing,
    entries: entries ?? this.entries,
    reviews: reviews ?? this.reviews,
    reviewCount: reviewCount ?? this.reviewCount,
    failure: failure ?? this.failure,
  );

  @override
  List<Object?> get props => [status, profile, counts, isFollowing, entries, reviews, reviewCount, failure];
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

  static const shownReviews = 5;

  Future<void> load() async {
    try {
      final profile = _profiles.getProfile(userId);
      final counts = _social.followCounts(userId);
      final following = isSelf ? Future.value(false) : _social.isFollowing(userId);
      final entries = isSelf ? Future.value(const <LibraryEntry>[]) : _library.getLibrary(userId);
      final reviews = _reviews.byUser(userId, limit: shownReviews);
      await waitAll([profile, counts, following, entries, reviews]);
      if (isClosed) return;
      final (reviews: shown, :total) = await reviews;
      emit(
        ProfileState(
          status: LoadStatus.success,
          profile: await profile,
          counts: await counts,
          isFollowing: await following,
          entries: await entries,
          reviews: shown,
          reviewCount: total,
        ),
      );
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, failure: AppFailure.from(e)));
    }
  }

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
    } catch (_) {
      if (!isClosed) emit(before);
      rethrow;
    }
  }

  void profileUpdated(Profile profile) => emit(state.copyWith(profile: profile));
}
