import 'package:equatable/equatable.dart';

/// Community numbers computed from real library data. Never invented.
class BookStats extends Equatable {
  const BookStats({this.averageRating, this.ratingCount = 0, this.readerCount = 0});

  static const empty = BookStats();

  final double? averageRating;
  final int ratingCount;
  final int readerCount;

  bool get hasRatings => ratingCount > 0 && averageRating != null;

  @override
  List<Object?> get props => [averageRating, ratingCount, readerCount];
}

/// A stored book with how many readers / activities back its ranking.
class RankedBook extends Equatable {
  const RankedBook(this.bookId, this.count);
  final String bookId;
  final int count;

  @override
  List<Object?> get props => [bookId, count];
}
