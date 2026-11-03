import 'package:bookmarkd/features/library/domain/rating.dart';
import 'package:bookmarkd/features/profile/domain/profile.dart';
import 'package:equatable/equatable.dart';

class Review extends Equatable {
  const Review({
    required this.id,
    required this.author,
    required this.bookId,
    required this.body,
    required this.createdAt,
    this.containsSpoilers = false,
    this.rating,
    this.bookTitle,
    this.coverUrl,
  });

  final String id;
  final Profile author;
  final String bookId;
  final String body;
  final bool containsSpoilers;
  final DateTime createdAt;
  final Rating? rating;
  final String? bookTitle;
  final String? coverUrl;

  @override
  List<Object?> get props => [id, author, bookId, body, containsSpoilers, createdAt, rating];
}

String? validateReviewBody(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Write a few words';
  if (v.length > 5000) return 'Keep it under 5000 characters';
  return null;
}
