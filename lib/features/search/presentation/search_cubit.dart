import 'dart:async';

import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/books/domain/catalog_query.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SearchState extends Equatable {
  const SearchState({
    this.text = '',
    this.mode = SearchMode.any,
    this.status = LoadStatus.initial,
    this.results = const [],
    this.hasMore = false,
    this.nextIndex = 0,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.failure,
  });

  final String text;
  final SearchMode mode;
  final LoadStatus status;
  final List<Book> results;
  final bool hasMore;
  final int nextIndex;
  final bool loadingMore;
  final bool loadMoreFailed;
  final AppFailure? failure;

  SearchState copyWith({
    String? text,
    SearchMode? mode,
    LoadStatus? status,
    List<Book>? results,
    bool? hasMore,
    int? nextIndex,
    bool? loadingMore,
    bool? loadMoreFailed,
    AppFailure? Function()? failure,
  }) => SearchState(
    text: text ?? this.text,
    mode: mode ?? this.mode,
    status: status ?? this.status,
    results: results ?? this.results,
    hasMore: hasMore ?? this.hasMore,
    nextIndex: nextIndex ?? this.nextIndex,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [text, mode, status, results, hasMore, nextIndex, loadingMore, loadMoreFailed, failure];
}

class SearchCubit extends Cubit<SearchState> {
  SearchCubit(this._catalog) : super(const SearchState());

  static const debounce = Duration(milliseconds: 300);

  final CatalogRepository _catalog;
  Timer? _timer;
  int _generation = 0;

  void submitted() {
    if (!(_timer?.isActive ?? false)) return;
    _timer!.cancel();
    _run(state.text, state.mode);
  }

  void queryChanged(String text) {
    _timer?.cancel();
    if (!CatalogQuery.parse(text).isSearchable) {
      _generation++;
      emit(SearchState(text: text, mode: state.mode));
      return;
    }
    emit(state.copyWith(text: text));
    _timer = Timer(debounce, () => _run(text, state.mode));
  }

  void modeChanged(SearchMode mode) {
    if (mode == state.mode) return;
    emit(state.copyWith(mode: mode));
    _timer?.cancel();
    if (CatalogQuery.parse(state.text).isSearchable) _run(state.text, mode);
  }

  Future<void> retry() => _run(state.text, state.mode);

  Future<void> _run(String text, SearchMode mode) async {
    final generation = ++_generation;
    emit(state.copyWith(status: LoadStatus.loading, loadingMore: false, loadMoreFailed: false, failure: () => null));
    try {
      final page = await _catalog.search(CatalogQuery.parse(text, mode: mode));
      if (generation != _generation || isClosed) return;
      emit(
        state.copyWith(
          status: LoadStatus.success,
          results: page.books,
          nextIndex: page.fetched,
          hasMore: page.fetched >= catalogPageSize,
        ),
      );
    } catch (e) {
      if (generation != _generation || isClosed) return;
      emit(state.copyWith(status: LoadStatus.failure, failure: () => AppFailure.from(e)));
    }
  }

  Future<void> loadMore({bool retry = false}) async {
    if (!state.hasMore || state.loadingMore || state.status != LoadStatus.success) return;
    if (state.loadMoreFailed && !retry) return;
    final generation = _generation;
    emit(state.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final page = await _catalog.search(CatalogQuery.parse(state.text, mode: state.mode), startIndex: state.nextIndex);
      if (generation != _generation || isClosed) return;
      final known = state.results.map((b) => b.key).toSet();
      emit(
        state.copyWith(
          results: [...state.results, ...page.books.where((b) => !known.contains(b.key))],
          nextIndex: state.nextIndex + page.fetched,
          hasMore: page.fetched >= catalogPageSize,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (generation != _generation || isClosed) return;
      emit(state.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
