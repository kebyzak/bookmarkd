import 'dart:typed_data';

import '../features/books/domain/book.dart';
import '../features/books/domain/book_stats.dart';
import '../features/books/domain/catalog_query.dart';
import '../features/library/domain/library_entry.dart';
import '../features/library/domain/reading_status.dart';
import '../features/profile/domain/profile.dart';
import '../features/reading/domain/progress_update.dart';
import '../features/reading/domain/reading_session.dart';
import '../features/reviews/domain/review.dart';
import '../features/social/domain/activity.dart';

/// Repository contracts. Each has a Supabase and a demo implementation.
/// All methods throw [AppFailure] on error.

enum SignUpResult { signedIn, confirmEmail }

abstract interface class AuthRepository {
  /// Emits the signed-in user id, or null. Replays the current value first.
  Stream<String?> userIdChanges();
  String? get currentUserId;
  Future<void> signIn({required String email, required String password});
  Future<SignUpResult> signUp({required String email, required String password});
  Future<void> sendPasswordReset(String email);
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
}

abstract interface class CatalogRepository {
  Future<List<Book>> search(CatalogQuery query, {int startIndex = 0});

  /// Resolves a catalog key (`gb:`, `ol:`, `isbn:`) to a book.
  Future<Book> lookup(String catalogKey);
}

abstract interface class BookRepository {
  Future<Book> getStoredBook(String bookId);

  /// Saves catalog metadata (deduplicated server-side). Idempotent.
  Future<Book> save(Book book);
  Future<BookStats> stats(String bookId);
  Future<List<Book>> popular({String? category, int limit = 20});
  Future<List<Book>> trending({int limit = 20});
}

abstract interface class LibraryRepository {
  Future<List<LibraryEntry>> getLibrary(String userId);
  Future<LibraryEntry> add(Book storedBook, ReadingStatus status);

  /// Persists status, dates, rating and favorite of [entry].
  Future<LibraryEntry> update(LibraryEntry entry);
  Future<void> remove(String entryId);
  Future<LibraryEntry> logProgress(String entryId, ProgressUpdate update);
  Future<List<ReadingSession>> sessions(String entryId);
}

abstract interface class ReviewRepository {
  Future<List<Review>> forBook(String bookId, {int limit = 20, int offset = 0});
  Future<List<Review>> byUser(String userId);
  Future<Review?> mine(String bookId);
  Future<Review> upsert({required String bookId, required String body, required bool containsSpoilers});
  Future<void> delete(String reviewId);
}

abstract interface class ActivityRepository {
  Future<FeedPage> feed({FeedCursor? before, int limit = 20});
  Future<void> like(String activityId);
  Future<void> unlike(String activityId);
}
