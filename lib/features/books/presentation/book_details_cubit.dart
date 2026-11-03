import 'dart:async';

import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/utils/wait_all.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/books/domain/book_stats.dart';
import 'package:bookmarkd/features/library/domain/library_entry.dart';
import 'package:bookmarkd/features/reviews/domain/review.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BookDetailsState extends Equatable {
  const BookDetailsState({
    this.status = LoadStatus.loading,
    this.book,
    this.stats = BookStats.empty,
    this.reviews = const [],
    this.failure,
  });

  final LoadStatus status;
  final Book? book;
  final BookStats stats;
  final List<Review> reviews;
  final AppFailure? failure;

  @override
  List<Object?> get props => [status, book, stats, reviews, failure];
}

class BookDetailsCubit extends Cubit<BookDetailsState> {
  BookDetailsCubit({
    required this.bookKey,
    required this._catalog,
    required this._books,
    required this._reviews,
    required Stream<LibraryEntry> librarySynced,
  }) : super(const BookDetailsState()) {
    _syncedSub = librarySynced.listen((e) {
      if (e.book.id != null && e.book.id == state.book?.id) refreshCommunity();
    });
  }

  final String bookKey;
  final CatalogRepository _catalog;
  final BookRepository _books;
  final ReviewRepository _reviews;
  late final StreamSubscription<LibraryEntry> _syncedSub;
  int _communityGeneration = 0;

  static bool isCatalogKey(String key) => key.contains(':');

  Future<void> load() async {
    emit(BookDetailsState(book: state.book));
    try {
      final book = await _resolve();
      if (isClosed) return;
      emit(BookDetailsState(status: LoadStatus.success, book: book));
      if (book.id != null) await refreshCommunity(book);
    } catch (e) {
      if (!isClosed) emit(BookDetailsState(status: LoadStatus.failure, failure: AppFailure.from(e)));
    }
  }

  Future<Book> _resolve() async {
    if (!isCatalogKey(bookKey)) return _books.getStoredBook(bookKey);
    final catalogBook = await _catalog.lookup(bookKey);
    final stored = await _books.findStored(catalogBook.ids);
    return stored ?? catalogBook;
  }

  Future<void> refreshCommunity([Book? book]) async {
    final b = book ?? state.book;
    if (b?.id == null) return;
    final generation = ++_communityGeneration;
    try {
      final stats = _books.stats(b!.id!);
      final reviews = _reviews.forBook(b.id!);
      await waitAll([stats, reviews]);
      if (!isClosed && generation == _communityGeneration) {
        emit(
          BookDetailsState(status: LoadStatus.success, book: state.book, stats: await stats, reviews: await reviews),
        );
      }
    } catch (_) {}
  }

  void bookStored(Book stored) {
    if (state.book?.id == stored.id) return;
    emit(BookDetailsState(status: LoadStatus.success, book: stored, stats: state.stats, reviews: state.reviews));
    refreshCommunity(stored);
  }

  @override
  Future<void> close() {
    _syncedSub.cancel();
    return super.close();
  }
}
