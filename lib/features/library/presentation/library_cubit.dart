import 'dart:async';

import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/library/domain/library_entry.dart';
import 'package:bookmarkd/features/library/domain/rating.dart';
import 'package:bookmarkd/features/library/domain/reading_status.dart';
import 'package:bookmarkd/features/library/domain/status_transition.dart';
import 'package:bookmarkd/features/reading/domain/progress_update.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LibraryState extends Equatable {
  const LibraryState({this.status = LoadStatus.initial, this.byId = const {}, this.adding = const {}, this.failure});

  final LoadStatus status;
  final Map<String, LibraryEntry> byId;
  final Set<String> adding;
  final AppFailure? failure;

  List<LibraryEntry> get entries => byId.values.toList();

  LibraryEntry? entryFor(Book book) {
    bool same(String? a, String? b) => a != null && a == b;
    for (final e in byId.values) {
      final b = e.book;
      if (same(b.id, book.id) ||
          same(b.ids.googleBooksId, book.ids.googleBooksId) ||
          same(b.ids.openLibraryId, book.ids.openLibraryId) ||
          same(b.ids.isbn13, book.ids.isbn13)) {
        return e;
      }
    }
    return null;
  }

  LibraryState copyWith({
    LoadStatus? status,
    Map<String, LibraryEntry>? byId,
    Set<String>? adding,
    AppFailure? Function()? failure,
  }) => LibraryState(
    status: status ?? this.status,
    byId: byId ?? this.byId,
    adding: adding ?? this.adding,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [status, byId, adding, failure];
}

class LibraryCubit extends Cubit<LibraryState> {
  LibraryCubit(this._library, this._books, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const LibraryState());

  final LibraryRepository _library;
  final BookRepository _books;
  final DateTime Function() _clock;
  String? _userId;

  Future<void> load(String userId) async {
    final refreshing = userId == _userId && state.status == LoadStatus.success;
    _userId = userId;
    if (!refreshing) emit(state.copyWith(status: LoadStatus.loading, failure: () => null));
    try {
      final entries = await _library.getLibrary(userId);
      emit(LibraryState(status: LoadStatus.success, byId: {for (final e in entries) e.id: e}, adding: state.adding));
    } catch (e) {
      final failure = AppFailure.from(e);
      if (refreshing) throw failure;
      emit(state.copyWith(status: LoadStatus.failure, failure: () => failure));
    }
  }

  Future<void> reload() async {
    if (_userId != null) await load(_userId!);
  }

  void clear() {
    _userId = null;
    emit(const LibraryState());
  }

  Future<LibraryEntry> add(Book book, ReadingStatus status) =>
      _addOrUpdate(book, (e) => transitionStatus(e, status, today: _clock()));

  Future<LibraryEntry> finish(Book book, FinishDate when) => _addOrUpdate(book, (e) => finishOn(e, when));

  Future<LibraryEntry> _addOrUpdate(Book book, LibraryEntry Function(LibraryEntry) shape) async {
    final existing = state.entryFor(book);
    if (existing != null) {
      await _optimistic(shape(existing));
      return state.byId[existing.id]!;
    }
    final key = book.key;
    final pending = _adding[key];
    if (pending != null) return pending;
    final future = _insert(book, shape).whenComplete(() {
      _adding.remove(key);
      if (!isClosed) emit(state.copyWith(adding: _adding.keys.toSet()));
    });
    _adding[key] = future;
    emit(state.copyWith(adding: _adding.keys.toSet()));
    return future;
  }

  final _adding = <String, Future<LibraryEntry>>{};

  Future<LibraryEntry> _insert(Book book, LibraryEntry Function(LibraryEntry) shape) async {
    final stored = await _books.save(book);
    final existing = state.entryFor(stored);
    if (existing != null) return existing;
    final entry = await _library.add(stored, shape);
    _put(entry);
    return entry;
  }

  Future<void> setStatus(LibraryEntry entry, ReadingStatus status) =>
      _optimistic(transitionStatus(entry, status, today: _clock()));

  Future<void> rate(LibraryEntry entry, Rating? rating) => _optimistic(entry.copyWith(rating: () => rating));

  Future<void> toggleFavorite(LibraryEntry entry) => _optimistic(entry.copyWith(isFavorite: !entry.isFavorite));

  Future<void> setDates(LibraryEntry entry, {DateTime? startedAt, DateTime? finishedAt}) =>
      _optimistic(entry.copyWith(startedAt: () => startedAt, finishedAt: () => finishedAt));

  Future<LibraryEntry> logProgress(LibraryEntry entry, ProgressUpdate update) async {
    final previous = state.byId[entry.id];
    _put(entry.copyWith(currentPage: () => update.page ?? entry.currentPage, progressPercent: () => update.percent));
    try {
      final saved = await _library.logProgress(entry.id, update);
      _put(saved);
      return saved;
    } catch (_) {
      if (previous != null) _put(previous);
      rethrow;
    }
  }

  Future<void> remove(LibraryEntry entry) async {
    final previous = state.byId[entry.id];
    emit(state.copyWith(byId: Map.of(state.byId)..remove(entry.id)));
    try {
      await _library.remove(entry.id);
      if (!_synced.isClosed) _synced.add(entry);
    } catch (_) {
      if (previous != null) _put(previous);
      rethrow;
    }
  }

  Stream<LibraryEntry> get synced => _synced.stream;
  final _synced = StreamController<LibraryEntry>.broadcast();

  final _writes = <String, Future<void>>{};
  final _latest = <String, int>{};

  Future<void> _optimistic(LibraryEntry next) async {
    final id = next.id;
    final previous = state.byId[id];
    final seq = _latest[id] = (_latest[id] ?? 0) + 1;
    _put(next);
    final write = (_writes[id] ?? Future<void>.value()).catchError((Object _) {}).then((_) => _library.update(next));
    _writes[id] = write;
    try {
      final saved = await write;
      if (_latest[id] != seq) return;
      _put(saved);
      if (!_synced.isClosed) _synced.add(saved);
    } catch (_) {
      if (_latest[id] != seq) return;
      if (previous != null) _put(previous);
      rethrow;
    } finally {
      if (_latest[id] == seq) _writes.remove(id);
    }
  }

  @override
  Future<void> close() {
    _synced.close();
    return super.close();
  }

  void _put(LibraryEntry entry) {
    if (isClosed) return;
    emit(state.copyWith(byId: {...state.byId, entry.id: entry}));
  }
}
