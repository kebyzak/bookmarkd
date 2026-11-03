import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/utils/wait_all.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/home/domain/recommendation.dart';
import 'package:bookmarkd/features/library/domain/library_entry.dart';
import 'package:bookmarkd/features/social/domain/activity.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeState extends Equatable {
  const HomeState({
    this.status = LoadStatus.loading,
    this.friends = const [],
    this.recommended = const [],
    this.recommendationGenre,
    this.unreadNotifications = 0,
  });

  final LoadStatus status;
  final List<Activity> friends;
  final List<Book> recommended;
  final String? recommendationGenre;
  final int unreadNotifications;

  @override
  List<Object?> get props => [status, friends, recommended, recommendationGenre, unreadNotifications];
}

class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._activity, this._books, this._social) : super(const HomeState());

  final ActivityRepository _activity;
  final BookRepository _books;
  final SocialRepository _social;

  Future<void> load({required String myId, required List<LibraryEntry> library}) async {
    final genre = topGenre(library);
    try {
      final feed = _activity.feed(limit: 15);
      final genreBooks = genre == null ? Future.value(const <Book>[]) : _books.popular(category: genre);
      final popular = _books.popular();
      final unread = _social.unreadNotificationCount().catchError((Object _) => 0);
      await waitAll([feed, genreBooks, popular, unread]);
      final friends = (await feed).items.where((a) => a.actor.id != myId).take(5).toList();
      final inGenre = excludeOwned(await genreBooks, library);
      final overall = excludeOwned(await popular, library);
      final useGenre = inGenre.length >= 3;
      if (isClosed) return;
      emit(
        HomeState(
          status: LoadStatus.success,
          friends: friends,
          recommended: (useGenre ? inGenre : overall).take(12).toList(),
          recommendationGenre: useGenre ? genre : null,
          unreadNotifications: await unread,
        ),
      );
    } catch (_) {
      if (!isClosed) emit(const HomeState(status: LoadStatus.failure));
    }
  }

  void notificationsSeen() => emit(
    HomeState(
      status: state.status,
      friends: state.friends,
      recommended: state.recommended,
      recommendationGenre: state.recommendationGenre,
    ),
  );
}
