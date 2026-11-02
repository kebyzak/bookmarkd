import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/repositories.dart';
import '../../../core/services/recent_searches_store.dart';
import '../../../core/utils/wait_all.dart';
import '../../../core/widgets/states.dart';
import '../../books/domain/book.dart';

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

  /// Genres taken from real community books, most common first.
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
      final r = await waitAll([_recent.load(), _books.trending(), _books.popular()]);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: LoadStatus.success,
          recent: r[0] as List<Book>,
          trending: r[1] as List<Book>,
          popular: r[2] as List<Book>,
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
    } catch (_) {
      // Genre browsing is optional; keep the chips usable.
    }
  }
}
