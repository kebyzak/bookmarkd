import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/repositories.dart';
import '../../../core/widgets/states.dart';
import '../../books/domain/book.dart';
import '../../books/domain/catalog_query.dart';

class SearchState extends Equatable {
  const SearchState({
    this.text = '',
    this.mode = SearchMode.any,
    this.status = LoadStatus.initial,
    this.results = const [],
    this.hasMore = false,
    this.loadingMore = false,
    this.failure,
  });

  final String text;
  final SearchMode mode;
  final LoadStatus status;
  final List<Book> results;
  final bool hasMore;
  final bool loadingMore;
  final AppFailure? failure;

  SearchState copyWith({
    String? text,
    SearchMode? mode,
    LoadStatus? status,
    List<Book>? results,
    bool? hasMore,
    bool? loadingMore,
    AppFailure? Function()? failure,
  }) => SearchState(
    text: text ?? this.text,
    mode: mode ?? this.mode,
    status: status ?? this.status,
    results: results ?? this.results,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [text, mode, status, results, hasMore, loadingMore, failure];
}

/// Debounced catalog search with pagination. Stale responses are dropped.
class SearchCubit extends Cubit<SearchState> {
  SearchCubit(this._catalog) : super(const SearchState());

  static const debounce = Duration(milliseconds: 400);

  final CatalogRepository _catalog;
  Timer? _timer;
  int _generation = 0;

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
    emit(state.copyWith(status: LoadStatus.loading, failure: () => null));
    try {
      final results = await _catalog.search(CatalogQuery.parse(text, mode: mode));
      if (generation != _generation || isClosed) return;
      emit(state.copyWith(status: LoadStatus.success, results: results, hasMore: results.length >= catalogPageSize));
    } catch (e) {
      if (generation != _generation || isClosed) return;
      emit(state.copyWith(status: LoadStatus.failure, failure: () => AppFailure.from(e)));
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore || state.status != LoadStatus.success) return;
    final generation = _generation;
    emit(state.copyWith(loadingMore: true));
    try {
      final more = await _catalog.search(
        CatalogQuery.parse(state.text, mode: state.mode),
        startIndex: state.results.length,
      );
      if (generation != _generation || isClosed) return;
      final known = state.results.map((b) => b.key).toSet();
      emit(
        state.copyWith(
          results: [...state.results, ...more.where((b) => !known.contains(b.key))],
          hasMore: more.length >= catalogPageSize,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (!isClosed) emit(state.copyWith(loadingMore: false, hasMore: false));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
