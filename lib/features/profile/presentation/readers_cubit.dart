import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/profile/domain/profile.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReadersState extends Equatable {
  const ReadersState({this.status = LoadStatus.loading, this.links = const [], this.failure});

  final LoadStatus status;
  final List<ReaderLink> links;
  final AppFailure? failure;

  @override
  List<Object?> get props => [status, links, failure];
}

class ReadersCubit extends Cubit<ReadersState> {
  ReadersCubit(this._fetch, this._social) : super(const ReadersState());

  final Future<List<ReaderLink>> Function() _fetch;
  final SocialRepository _social;

  Future<void> load() async {
    try {
      final links = await _fetch();
      if (!isClosed) emit(ReadersState(status: LoadStatus.success, links: links));
    } catch (e) {
      if (!isClosed) emit(ReadersState(status: LoadStatus.failure, links: state.links, failure: AppFailure.from(e)));
    }
  }

  Future<void> toggleFollow(String userId) async {
    final before = state;
    final link = before.links.firstWhere((l) => l.profile.id == userId);
    final following = !link.following;
    _set(userId, following);
    try {
      following ? await _social.follow(userId) : await _social.unfollow(userId);
    } catch (_) {
      if (!isClosed) emit(before);
      rethrow;
    }
  }

  void _set(String userId, bool following) => emit(
    ReadersState(
      status: state.status,
      links: [for (final l in state.links) l.profile.id == userId ? l.copyWith(following: following) : l],
    ),
  );
}
