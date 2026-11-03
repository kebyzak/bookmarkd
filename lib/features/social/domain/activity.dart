import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/library/domain/rating.dart';
import 'package:bookmarkd/features/profile/domain/profile.dart';
import 'package:equatable/equatable.dart';

enum ActivityType {
  wantToRead('want_to_read', 'wants to read'),
  started('started', 'started reading'),
  finished('finished', 'finished reading'),
  dnf('dnf', 'stopped reading'),
  rated('rated', 'rated'),
  reviewed('reviewed', 'reviewed');

  const ActivityType(this.dbValue, this.verb);

  final String dbValue;
  final String verb;

  static ActivityType fromDb(String v) => values.firstWhere((t) => t.dbValue == v);
}

class Activity extends Equatable {
  const Activity({
    required this.id,
    required this.type,
    required this.actor,
    required this.book,
    required this.createdAt,
    this.rating,
    this.reviewExcerpt,
    this.likeCount = 0,
    this.likedByMe = false,
  });

  final String id;
  final ActivityType type;
  final Profile actor;
  final Book book;
  final DateTime createdAt;
  final Rating? rating;
  final String? reviewExcerpt;
  final int likeCount;
  final bool likedByMe;

  Activity toggledLike() => Activity(
    id: id,
    type: type,
    actor: actor,
    book: book,
    createdAt: createdAt,
    rating: rating,
    reviewExcerpt: reviewExcerpt,
    likedByMe: !likedByMe,
    likeCount: likeCount + (likedByMe ? -1 : 1),
  );

  @override
  List<Object?> get props => [id, type, actor, book, createdAt, rating, reviewExcerpt, likeCount, likedByMe];
}

class FeedCursor extends Equatable {
  const FeedCursor(this.createdAt, this.id);

  final DateTime createdAt;
  final String id;

  @override
  List<Object?> get props => [createdAt, id];
}

class FeedPage {
  const FeedPage(this.items, this.next);

  final List<Activity> items;

  final FeedCursor? next;
}
