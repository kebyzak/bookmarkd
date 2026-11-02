import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/repositories.dart';
import '../../../core/widgets/states.dart';
import '../domain/activity.dart';

class FeedState extends Equatable {
  const FeedState({
    this.status = LoadStatus.initial,
    this.items = const [],
    this.next,
    this.loadingMore = false,
    this.failure,
  });

  final LoadStatus status;
  final List<Activity> items;
  final FeedCursor? next;
  final bool loadingMore;
  final AppFailure? failure;

  bool get hasMore => next != null;

  FeedState copyWith({
    LoadStatus? status,
    List<Activity>? items,
    FeedCursor? Function()? next,
    bool? loadingMore,
    AppFailure? Function()? failure,
  }) => FeedState(
    status: status ?? this.status,
    items: items ?? this.items,
    next: next != null ? next() : this.next,
    loadingMore: loadingMore ?? this.loadingMore,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [status, items, next, loadingMore, failure];
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

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    emit(state.copyWith(loadingMore: true));
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
      // Keep what is loaded; scrolling again retries.
      if (!isClosed) emit(state.copyWith(loadingMore: false));
    }
  }

  Future<void> toggleLike(Activity activity) async {
    final toggled = activity.toggledLike();
    _replace(toggled);
    try {
      activity.likedByMe ? await _activity.unlike(activity.id) : await _activity.like(activity.id);
    } catch (e) {
      _replace(activity);
      throw AppFailure.from(e);
    }
  }

  void _replace(Activity a) {
    if (isClosed) return;
    emit(state.copyWith(items: [for (final i in state.items) i.id == a.id ? a : i]));
  }
}
