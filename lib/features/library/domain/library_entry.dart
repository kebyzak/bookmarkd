import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:equatable/equatable.dart';

import 'rating.dart';
import 'reading_status.dart';

class LibraryEntry extends Equatable {
  const LibraryEntry({
    required this.id,
    required this.userId,
    required this.book,
    required this.status,
    required this.addedAt,
    this.currentPage,
    this.progressPercent,
    this.rating,
    this.isFavorite = false,
    this.startedAt,
    this.finishedAt,
  });

  final String id;
  final String userId;
  final Book book;
  final ReadingStatus status;
  final int? currentPage;
  final int? progressPercent;
  final Rating? rating;
  final bool isFavorite;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime addedAt;

  double get progress {
    if (status == ReadingStatus.finished) return 1;
    final pages = book.pageCount;
    if (currentPage != null && pages != null) return (currentPage! / pages).clamp(0, 1);
    return ((progressPercent ?? 0) / 100).clamp(0, 1);
  }

  int get progressPercentDisplay => (progress * 100).round();

  String get progressLabel {
    final pages = book.pageCount;
    if (currentPage != null && pages != null) return 'Page $currentPage of $pages · $progressPercentDisplay%';
    return progressPercentDisplay == 0 ? 'Not started' : '$progressPercentDisplay%';
  }

  LibraryEntry copyWith({
    ReadingStatus? status,
    int? Function()? currentPage,
    int? Function()? progressPercent,
    Rating? Function()? rating,
    bool? isFavorite,
    DateTime? Function()? startedAt,
    DateTime? Function()? finishedAt,
  }) => LibraryEntry(
    id: id,
    userId: userId,
    book: book,
    addedAt: addedAt,
    status: status ?? this.status,
    currentPage: currentPage != null ? currentPage() : this.currentPage,
    progressPercent: progressPercent != null ? progressPercent() : this.progressPercent,
    rating: rating != null ? rating() : this.rating,
    isFavorite: isFavorite ?? this.isFavorite,
    startedAt: startedAt != null ? startedAt() : this.startedAt,
    finishedAt: finishedAt != null ? finishedAt() : this.finishedAt,
  );

  @override
  List<Object?> get props => [
    id,
    book,
    status,
    currentPage,
    progressPercent,
    rating,
    isFavorite,
    startedAt,
    finishedAt,
    addedAt,
  ];
}
