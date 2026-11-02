import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/repositories.dart';
import '../../../core/utils/wait_all.dart';
import '../../../core/widgets/states.dart';
import '../../books/domain/book.dart';
import '../../library/domain/library_entry.dart';
import '../../social/domain/activity.dart';
import '../domain/recommendation.dart';

class HomeState extends Equatable {
  const HomeState({
    this.status = LoadStatus.loading,
    this.friends = const [],
    this.recommended = const [],
    this.recommendationGenre,
  });

  final LoadStatus status;
  final List<Activity> friends;
  final List<Book> recommended;

  /// The genre the recommendations are based on; null means "popular overall".
  final String? recommendationGenre;

  @override
  List<Object?> get props => [status, friends, recommended, recommendationGenre];
}

/// Social and discovery parts of Home. The reader's own books come from LibraryCubit.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._activity, this._books) : super(const HomeState());

  final ActivityRepository _activity;
  final BookRepository _books;

  Future<void> load({required String myId, required List<LibraryEntry> library}) async {
    final genre = topGenre(library);
    try {
      final r = await waitAll([
        _activity.feed(limit: 15),
        genre == null ? Future.value(const <Book>[]) : _books.popular(category: genre),
        _books.popular(),
      ]);
      final friends = (r[0] as FeedPage).items.where((a) => a.actor.id != myId).take(5).toList();
      final inGenre = excludeOwned(r[1] as List<Book>, library);
      final overall = excludeOwned(r[2] as List<Book>, library);
      final useGenre = inGenre.length >= 3;
      if (isClosed) return;
      emit(
        HomeState(
          status: LoadStatus.success,
          friends: friends,
          recommended: (useGenre ? inGenre : overall).take(12).toList(),
          recommendationGenre: useGenre ? genre : null,
        ),
      );
    } catch (_) {
      if (!isClosed) emit(const HomeState(status: LoadStatus.failure));
    }
  }
}
