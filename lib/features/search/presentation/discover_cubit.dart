import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/services/recent_searches_store.dart';
import 'package:bookmarkd/core/utils/wait_all.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DiscoverState extends Equatable {
  const DiscoverState({
    this.status = LoadStatus.loading,
    this.recent = const [],
    this.trending = const [],
    this.popular = const [],
    this.genre,
    this.genreBooks = const [],
    this.failure,
  });

  final LoadStatus status;
  final List<Book> recent;
  final List<Book> trending;
  final List<Book> popular;
  final String? genre;
  final List<Book> genreBooks;
  final AppFailure? failure;

  List<String> get genres {
    final counts = <String, int>{};
    for (final b in {...trending, ...popular}) {
      for (final c in b.categories) {
        counts.update(c, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    return (counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!))).take(10).toList();
  }

  DiscoverState copyWith({
    LoadStatus? status,
    List<Book>? recent,
    List<Book>? trending,
    List<Book>? popular,
    String? Function()? genre,
    List<Book>? genreBooks,
    AppFailure? Function()? failure,
  }) => DiscoverState(
    status: status ?? this.status,
    recent: recent ?? this.recent,
    trending: trending ?? this.trending,
    popular: popular ?? this.popular,
    genre: genre != null ? genre() : this.genre,
    genreBooks: genreBooks ?? this.genreBooks,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [status, recent, trending, popular, genre, genreBooks, failure];
}

class DiscoverCubit extends Cubit<DiscoverState> {
  DiscoverCubit(this._books, this._recent) : super(const DiscoverState());

  final BookRepository _books;
  final RecentSearchesStore _recent;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, failure: () => null));
    try {
      final recent = _recent.load();
      final trending = _books.trending();
      final popular = _books.popular();
      await waitAll([recent, trending, popular]);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: LoadStatus.success,
          recent: await recent,
          trending: await trending,
          popular: await popular,
        ),
      );
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, failure: () => AppFailure.from(e)));
    }
  }

  Future<void> refreshRecent() async {
    final recent = await _recent.load();
    if (!isClosed) emit(state.copyWith(recent: recent));
  }

  Future<void> clearRecent() async {
    await _recent.clear();
    if (!isClosed) emit(state.copyWith(recent: const []));
  }

  Future<void> selectGenre(String? genre) async {
    emit(state.copyWith(genre: () => genre, genreBooks: const []));
    if (genre == null) return;
    try {
      final books = await _books.popular(category: genre);
      if (!isClosed && state.genre == genre) emit(state.copyWith(genreBooks: books));
    } catch (_) {}
  }
}
