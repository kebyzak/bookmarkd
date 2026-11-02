import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/repositories.dart';
import '../../../core/widgets/states.dart';
import '../../books/domain/book.dart';
import '../../reading/domain/progress_update.dart';
import '../domain/library_entry.dart';
import '../domain/rating.dart';
import '../domain/reading_status.dart';
import '../domain/status_transition.dart';

class LibraryState extends Equatable {
  const LibraryState({this.status = LoadStatus.initial, this.byId = const {}, this.failure});

  final LoadStatus status;

  /// Entries keyed by entry id.
  final Map<String, LibraryEntry> byId;
  final AppFailure? failure;

  List<LibraryEntry> get entries => byId.values.toList();

  /// Finds the entry for a stored or catalog book (matched by work id or external ids).
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

  LibraryState copyWith({LoadStatus? status, Map<String, LibraryEntry>? byId, AppFailure? Function()? failure}) =>
      LibraryState(
        status: status ?? this.status,
        byId: byId ?? this.byId,
        failure: failure != null ? failure() : this.failure,
      );

  @override
  List<Object?> get props => [status, byId, failure];
}

/// The signed-in reader's library. The single writer for library state:
/// every screen reads it from here, so all tabs stay in sync.
class LibraryCubit extends Cubit<LibraryState> {
  LibraryCubit(this._library, this._books, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const LibraryState());

  final LibraryRepository _library;
  final BookRepository _books;
  final DateTime Function() _clock;
  String? _userId;

  Future<void> load(String userId) async {
    _userId = userId;
    emit(state.copyWith(status: LoadStatus.loading, failure: () => null));
    try {
      final entries = await _library.getLibrary(userId);
      emit(LibraryState(status: LoadStatus.success, byId: {for (final e in entries) e.id: e}));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, failure: () => AppFailure.from(e)));
    }
  }

  Future<void> reload() async {
    if (_userId != null) await load(_userId!);
  }

  void clear() {
    _userId = null;
    emit(const LibraryState());
  }

  /// Not optimistic: the book needs server ids first.
  Future<LibraryEntry> add(Book book, ReadingStatus status) async {
    final existing = state.entryFor(book);
    if (existing != null) {
      await setStatus(existing, status);
      return state.byId[existing.id]!;
    }
    final stored = await _guard(() => _books.save(book));
    final entry = await _guard(() => _library.add(stored, status));
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
      final saved = await _guard(() => _library.logProgress(entry.id, update));
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
      await _guard(() => _library.remove(entry.id));
    } catch (_) {
      if (previous != null) _put(previous);
      rethrow;
    }
  }

  /// Applies [next] now, persists it, and rolls back if persisting fails.
  Future<void> _optimistic(LibraryEntry next) async {
    final previous = state.byId[next.id];
    _put(next);
    try {
      _put(await _guard(() => _library.update(next)));
    } catch (_) {
      if (previous != null) _put(previous);
      rethrow;
    }
  }

  void _put(LibraryEntry entry) {
    if (isClosed) return;
    emit(state.copyWith(byId: {...state.byId, entry.id: entry}));
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
