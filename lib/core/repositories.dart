import 'dart:typed_data';

import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/books/domain/book_stats.dart';
import 'package:bookmarkd/features/books/domain/catalog_query.dart';
import 'package:bookmarkd/features/library/domain/library_entry.dart';
import 'package:bookmarkd/features/profile/domain/profile.dart';
import 'package:bookmarkd/features/reading/domain/progress_update.dart';
import 'package:bookmarkd/features/reading/domain/reading_session.dart';
import 'package:bookmarkd/features/reviews/domain/review.dart';
import 'package:bookmarkd/features/social/domain/activity.dart';

enum SignUpResult { signedIn, confirmEmail }

abstract interface class AuthRepository {
  Stream<String?> userIdChanges();

  String? get currentUserId;

  Future<void> signIn({required String email, required String password});

  Future<SignUpResult> signUp({required String email, required String password});

  Future<void> sendPasswordReset(String email);

  Stream<void> passwordRecoveries();

  Future<void> updatePassword(String password);

  Future<void> signOut();
}

abstract interface class ProfileRepository {
  Future<Profile> getProfile(String userId);

  Future<Profile> updateProfile(Profile profile);

  Future<bool> isUsernameAvailable(String username, {required String exceptUserId});

  Future<String> uploadAvatar(String userId, Uint8List bytes, {required String extension});

  Future<List<Profile>> searchProfiles(String query);
}

abstract interface class SocialRepository {
  Future<FollowCounts> followCounts(String userId);

  Future<bool> isFollowing(String otherUserId);

  Future<void> follow(String otherUserId);

  Future<void> unfollow(String otherUserId);

  Future<List<ReaderLink>> followers(String userId);

  Future<List<ReaderLink>> following(String userId);

  Future<List<ReaderLink>> followNotifications();

  Future<int> unreadNotificationCount();

  Future<void> markNotificationsRead();
}

typedef CatalogPage = ({List<Book> books, int fetched});

abstract interface class CatalogRepository {
  Future<CatalogPage> search(CatalogQuery query, {int startIndex = 0});

  Future<Book> lookup(String catalogKey);
}

abstract interface class BookRepository {
  Future<Book> getStoredBook(String bookId);

  Future<Book?> findStored(ExternalIds ids);

  Future<Book> save(Book book);

  Future<BookStats> stats(String bookId);

  Future<List<Book>> popular({String? category, int limit = 20});

  Future<List<Book>> trending({int limit = 20});
}

abstract interface class LibraryRepository {
  Future<List<LibraryEntry>> getLibrary(String userId);

  Future<LibraryEntry> add(Book storedBook, LibraryEntry Function(LibraryEntry blank) shape);

  Future<LibraryEntry> update(LibraryEntry entry);

  Future<void> remove(String entryId);

  Future<LibraryEntry> logProgress(String entryId, ProgressUpdate update);

  Future<List<ReadingSession>> sessions(String entryId);
}

abstract interface class ReviewRepository {
  Future<List<Review>> forBook(String bookId, {int limit = 20, int offset = 0});

  Future<({List<Review> reviews, int total})> byUser(String userId, {required int limit});

  Future<Review?> mine(String bookId);

  Future<Review> upsert({required String bookId, required String body, required bool containsSpoilers});

  Future<void> delete(String reviewId);
}

abstract interface class ActivityRepository {
  Future<FeedPage> feed({FeedCursor? before, int limit = 20});

  Future<void> like(String activityId);

  Future<void> unlike(String activityId);
}
