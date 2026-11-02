import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/repositories.dart';
import '../../../core/utils/wait_all.dart';
import '../../../core/widgets/states.dart';
import '../../reviews/domain/review.dart';
import '../domain/book.dart';
import '../domain/book_stats.dart';

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

/// Resolves a route key to a book, preferring the stored copy so community
/// stats and reviews can be shown, then loads those.
class BookDetailsCubit extends Cubit<BookDetailsState> {
  BookDetailsCubit({required this.bookKey, required this._catalog, required this._books, required this._reviews})
    : super(const BookDetailsState());

  final String bookKey;
  final CatalogRepository _catalog;
  final BookRepository _books;
  final ReviewRepository _reviews;

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

  /// Stats and reviews are secondary: failures there do not hide the book.
  Future<void> refreshCommunity([Book? book]) async {
    final b = book ?? state.book;
    if (b?.id == null) return;
    try {
      final r = await waitAll([_books.stats(b!.id!), _reviews.forBook(b.id!)]);
      if (!isClosed) {
        emit(
          BookDetailsState(
            status: LoadStatus.success,
            book: state.book,
            stats: r[0] as BookStats,
            reviews: r[1] as List<Review>,
          ),
        );
      }
    } catch (_) {
      // Leave the book visible without community data.
    }
  }

  /// Called after the reader adds the book, so later loads use internal ids.
  void bookStored(Book stored) {
    if (state.book?.id == stored.id) return;
    emit(BookDetailsState(status: LoadStatus.success, book: stored, stats: state.stats, reviews: state.reviews));
    refreshCommunity(stored);
  }
}
