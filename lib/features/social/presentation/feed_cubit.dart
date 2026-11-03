import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/social/domain/activity.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FeedState extends Equatable {
  const FeedState({
    this.status = LoadStatus.initial,
    this.items = const [],
    this.next,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.failure,
  });

  final LoadStatus status;
  final List<Activity> items;
  final FeedCursor? next;
  final bool loadingMore;
  final bool loadMoreFailed;
  final AppFailure? failure;

  bool get hasMore => next != null;

  FeedState copyWith({
    LoadStatus? status,
    List<Activity>? items,
    FeedCursor? Function()? next,
    bool? loadingMore,
    bool? loadMoreFailed,
    AppFailure? Function()? failure,
  }) => FeedState(
    status: status ?? this.status,
    items: items ?? this.items,
    next: next != null ? next() : this.next,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [status, items, next, loadingMore, loadMoreFailed, failure];
}

class FeedCubit extends Cubit<FeedState> {
  FeedCubit(this._activity, {this.pageSize = 20}) : super(const FeedState());

  final ActivityRepository _activity;
  final int pageSize;

  Future<void> refresh() async {
    if (state.items.isEmpty) emit(state.copyWith(status: LoadStatus.loading, failure: () => null));
    try {
      final page = await _activity.feed(limit: pageSize);
      if (!isClosed) emit(FeedState(status: LoadStatus.success, items: page.items, next: page.next));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, failure: () => AppFailure.from(e)));
    }
  }

  Future<void> loadMore({bool retry = false}) async {
    if (!state.hasMore || state.loadingMore || (state.loadMoreFailed && !retry)) return;
    emit(state.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final page = await _activity.feed(before: state.next, limit: pageSize);
      final known = state.items.map((a) => a.id).toSet();
      if (!isClosed) {
        emit(
          state.copyWith(
            items: [...state.items, ...page.items.where((a) => !known.contains(a.id))],
            next: () => page.next,
            loadingMore: false,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) emit(state.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }

  Future<void> toggleLike(Activity activity) async {
    final toggled = activity.toggledLike();
    _replace(toggled);
    try {
      activity.likedByMe ? await _activity.unlike(activity.id) : await _activity.like(activity.id);
    } catch (_) {
      _replace(activity);
      rethrow;
    }
  }

  void _replace(Activity a) {
    if (isClosed) return;
    emit(state.copyWith(items: [for (final i in state.items) i.id == a.id ? a : i]));
  }
}
