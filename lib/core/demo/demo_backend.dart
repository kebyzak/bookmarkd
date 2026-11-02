import 'dart:async';
import 'dart:typed_data';

import '../../features/books/domain/book.dart';
import '../../features/books/domain/book_stats.dart';
import '../../features/library/domain/library_entry.dart';
import '../../features/library/domain/rating.dart';
import '../../features/library/domain/reading_status.dart';
import '../../features/library/domain/status_transition.dart';
import '../../features/profile/domain/profile.dart';
import '../../features/reading/domain/progress_update.dart';
import '../../features/reading/domain/reading_session.dart';
import '../../features/reviews/domain/review.dart';
import '../../features/social/domain/activity.dart';
import '../errors/app_failure.dart';
import '../repositories.dart';
import 'demo_seed.dart';

/// In-memory stand-in for Supabase, used when no credentials are configured.
/// One store backs every repository so the app behaves consistently, and it
/// emits activities the same way the database triggers do.
/// Data lives only for the app session.
class DemoBackend
    implements
        AuthRepository,
        ProfileRepository,
        SocialRepository,
        BookRepository,
        LibraryRepository,
        ReviewRepository,
        ActivityRepository {
  DemoBackend({DateTime Function()? clock, this.latency = const Duration(milliseconds: 250), bool seed = true})
    : _clock = clock ?? DateTime.now {
    if (seed) seedDemoData(this);
  }

  final DateTime Function() _clock;
  final Duration latency;

  final profiles = <String, Profile>{};
  final books = <String, Book>{};
  final entries = <String, LibraryEntry>{};
  final reviews = <String, Review>{};
  final follows = <(String, String)>{};
  final activities = <Activity>[];
  final likes = <(String, String)>{};
  final sessionsByEntry = <String, List<ReadingSession>>{};

  final _user = StreamController<String?>.broadcast();
  String? _currentUserId;
  int _seq = 0;

  String nextId(String prefix) => '$prefix-${++_seq}';
  DateTime get now => _clock();

  Future<T> _run<T>(T Function() body) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return body();
  }

  String get _me => _currentUserId ?? (throw const AppFailure.unauthorized());

  // ───────── auth ─────────

  @override
  String? get currentUserId => _currentUserId;

  @override
  Stream<String?> userIdChanges() async* {
    yield _currentUserId;
    yield* _user.stream;
  }

  /// Any email with a 6+ character password signs in as the local demo reader.
  @override
  Future<void> signIn({required String email, required String password}) => _run(() {
    if (password.length < 6) throw const AppFailure(FailureKind.unauthorized, 'Invalid email or password.');
    final id = 'me-${email.trim().toLowerCase()}';
    profiles.putIfAbsent(id, () => Profile(id: id));
    for (final friend in demoFriendIds) {
      follows.add((id, friend));
    }
    _currentUserId = id;
    _user.add(id);
  });

  @override
  Future<SignUpResult> signUp({required String email, required String password}) async {
    await signIn(email: email, password: password);
    return SignUpResult.signedIn;
  }

  @override
  Future<void> sendPasswordReset(String email) => _run(() {});

  @override
  Future<void> signOut() => _run(() {
    _currentUserId = null;
    _user.add(null);
  });

  // ───────── profiles & social ─────────

  @override
  Future<Profile> getProfile(String userId) =>
      _run(() => profiles[userId] ?? (throw const AppFailure.notFound('Reader not found.')));

  @override
  Future<Profile> updateProfile(Profile profile) => _run(() {
    if (profile.id != _me) throw const AppFailure.unauthorized();
    if (profile.username != null && !_usernameFree(profile.username!, profile.id)) {
      throw const AppFailure.conflict('That username is taken.');
    }
    return profiles[profile.id] = profile;
  });

  bool _usernameFree(String username, String exceptUserId) =>
      !profiles.values.any((p) => p.username == username && p.id != exceptUserId);

  @override
  Future<bool> isUsernameAvailable(String username, {required String exceptUserId}) =>
      _run(() => _usernameFree(username, exceptUserId));

  @override
  bool get canUploadAvatars => false;

  /// Demo mode has no file storage; avatars stay as initials.
  @override
  Future<String> uploadAvatar(String userId, Uint8List bytes, {required String extension}) =>
      _run(() => throw const AppFailure.validation('Avatar upload needs a live Supabase backend.'));

  @override
  Future<List<Profile>> searchProfiles(String query) => _run(() {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const <Profile>[];
    return profiles.values
        .where((p) => p.onboarded && ((p.username ?? '').contains(q) || p.name.toLowerCase().contains(q)))
        .toList();
  });

  @override
  Future<FollowCounts> followCounts(String userId) => _run(
    () => FollowCounts(
      followers: follows.where((f) => f.$2 == userId).length,
      following: follows.where((f) => f.$1 == userId).length,
    ),
  );

  @override
  Future<bool> isFollowing(String otherUserId) => _run(() => follows.contains((_me, otherUserId)));

  @override
  Future<void> follow(String otherUserId) => _run(() {
    if (otherUserId == _me) throw const AppFailure.validation("You can't follow yourself.");
    follows.add((_me, otherUserId));
  });

  @override
  Future<void> unfollow(String otherUserId) => _run(() => follows.remove((_me, otherUserId)));

  // ───────── books ─────────

  @override
  Future<Book> getStoredBook(String bookId) =>
      _run(() => books[bookId] ?? (throw const AppFailure.notFound('Book not found.')));

  @override
  Future<Book?> findStored(ExternalIds ids) => _run(() => _match(ids));

  @override
  Future<Book> save(Book book) => _run(() => saveSync(book));

  /// Same matching order as `upsert_catalog_book`.
  Book saveSync(Book book) {
    if (book.isStored) return book;
    final existing = _match(book.ids);
    if (existing != null) return existing;
    final id = nextId('book');
    return books[id] = book.stored(id: id, editionId: 'ed-$id');
  }

  Book? _match(ExternalIds ids) {
    bool same(String? a, String? b) => a != null && a == b;
    return books.values
        .where(
          (b) =>
              same(b.ids.googleBooksId, ids.googleBooksId) ||
              same(b.ids.openLibraryId, ids.openLibraryId) ||
              same(b.ids.isbn13, ids.isbn13) ||
              same(b.ids.isbn10, ids.isbn10),
        )
        .firstOrNull;
  }

  @override
  Future<BookStats> stats(String bookId) => _run(() {
    final forBook = entries.values.where((e) => e.book.id == bookId && _visible(e.userId));
    final rated = forBook.map((e) => e.rating).nonNulls.toList();
    return BookStats(
      readerCount: forBook.length,
      ratingCount: rated.length,
      averageRating: rated.isEmpty ? null : rated.fold<double>(0, (s, r) => s + r.stars) / rated.length,
    );
  });

  @override
  Future<List<Book>> popular({String? category, int limit = 20}) => _run(() {
    final counts = <String, int>{};
    for (final e in entries.values) {
      if (category == null || e.book.categories.contains(category)) {
        counts.update(e.book.id!, (c) => c + 1, ifAbsent: () => 1);
      }
    }
    return _ranked(counts, limit);
  });

  @override
  Future<List<Book>> trending({int limit = 20}) => _run(() {
    final since = now.subtract(const Duration(days: 7));
    final counts = <String, int>{};
    for (final a in activities.where((a) => a.createdAt.isAfter(since))) {
      counts.update(a.book.id!, (c) => c + 1, ifAbsent: () => 1);
    }
    return _ranked(counts, limit);
  });

  List<Book> _ranked(Map<String, int> counts, int limit) {
    final ids = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return ids.take(limit).map((id) => books[id]!).toList();
  }

  bool _visible(String ownerId) => ownerId == _currentUserId || !(profiles[ownerId]?.isPrivate ?? false);

  // ───────── library ─────────

  @override
  Future<List<LibraryEntry>> getLibrary(String userId) => _run(() {
    if (!_visible(userId)) return const <LibraryEntry>[];
    return entries.values.where((e) => e.userId == userId).toList()..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  });

  @override
  Future<LibraryEntry> add(Book storedBook, ReadingStatus status) => _run(() => addSync(_me, storedBook, status));

  LibraryEntry addSync(String userId, Book book, ReadingStatus status, {DateTime? at, Rating? rating}) {
    final existing = entries.values.where((e) => e.userId == userId && e.book.id == book.id).firstOrNull;
    if (existing != null) return _store(transitionStatus(existing, status, today: now));
    final blank = LibraryEntry(
      id: nextId('entry'),
      userId: userId,
      book: book,
      status: ReadingStatus.wantToRead,
      addedAt: at ?? now,
    );
    final entry = transitionStatus(blank, status, today: at ?? now).copyWith(rating: () => rating);
    entries[entry.id] = entry;
    _emit(userId, _activityFor(status), book, rating: entry.rating, at: at);
    return entry;
  }

  @override
  Future<LibraryEntry> update(LibraryEntry entry) => _run(() => _store(entry));

  LibraryEntry _store(LibraryEntry entry) {
    final old = entries[entry.id];
    if (old == null || old.userId != _currentUserId) throw const AppFailure.notFound();
    entries[entry.id] = entry;
    if (old.status != entry.status) _emit(entry.userId, _activityFor(entry.status), entry.book, rating: entry.rating);
    if (entry.rating != null && entry.rating != old.rating) {
      _emit(entry.userId, ActivityType.rated, entry.book, rating: entry.rating);
    }
    return entry;
  }

  @override
  Future<void> remove(String entryId) => _run(() {
    final e = entries[entryId];
    if (e == null || e.userId != _me) throw const AppFailure.notFound();
    entries.remove(entryId);
    sessionsByEntry.remove(entryId);
  });

  @override
  Future<LibraryEntry> logProgress(String entryId, ProgressUpdate update) => _run(() {
    final e = entries[entryId];
    if (e == null || e.userId != _me) throw const AppFailure.notFound();
    sessionsByEntry
        .putIfAbsent(entryId, () => [])
        .insert(
          0,
          ReadingSession(
            id: nextId('session'),
            fromPage: e.currentPage,
            toPage: update.page,
            percent: update.percent,
            readOn: now,
          ),
        );
    final moved = e.status == ReadingStatus.wantToRead ? transitionStatus(e, ReadingStatus.reading, today: now) : e;
    return _store(
      moved.copyWith(
        currentPage: () => update.page,
        progressPercent: () => update.percent,
        startedAt: () => moved.startedAt ?? now,
      ),
    );
  });

  @override
  Future<List<ReadingSession>> sessions(String entryId) => _run(() => List.of(sessionsByEntry[entryId] ?? const []));

  // ───────── reviews ─────────

  @override
  Future<List<Review>> forBook(String bookId, {int limit = 20, int offset = 0}) => _run(() {
    final list = reviews.values.where((r) => r.bookId == bookId && _visible(r.author.id)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.skip(offset).take(limit).map(_withCurrentAuthor).toList();
  });

  @override
  Future<List<Review>> byUser(String userId) => _run(() {
    if (!_visible(userId)) return const <Review>[];
    return reviews.values.where((r) => r.author.id == userId).map(_withCurrentAuthor).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  });

  @override
  Future<Review?> mine(String bookId) => _run(
    () => reviews.values.where((r) => r.bookId == bookId && r.author.id == _me).map(_withCurrentAuthor).firstOrNull,
  );

  @override
  Future<Review> upsert({required String bookId, required String body, required bool containsSpoilers}) =>
      _run(() => upsertSync(_me, bookId, body, containsSpoilers));

  Review upsertSync(String userId, String bookId, String body, bool spoilers, {DateTime? at}) {
    final error = validateReviewBody(body);
    if (error != null) throw AppFailure.validation(error);
    final existing = reviews.values.where((r) => r.bookId == bookId && r.author.id == userId).firstOrNull;
    final book = books[bookId] ?? (throw const AppFailure.notFound());
    final review = Review(
      id: existing?.id ?? nextId('review'),
      author: profiles[userId]!,
      bookId: bookId,
      body: body.trim(),
      containsSpoilers: spoilers,
      createdAt: existing?.createdAt ?? at ?? now,
      bookTitle: book.title,
      coverUrl: book.coverUrl,
    );
    reviews[review.id] = review;
    if (existing == null) {
      _emit(userId, ActivityType.reviewed, book, rating: _ratingOf(userId, bookId), excerpt: review.body, at: at);
    }
    return review;
  }

  @override
  Future<void> delete(String reviewId) => _run(() {
    final review = reviews[reviewId];
    if (review?.author.id != _me) throw const AppFailure.notFound();
    reviews.remove(reviewId);
    activities.removeWhere(
      (a) => a.type == ActivityType.reviewed && a.actor.id == review!.author.id && a.book.id == review.bookId,
    );
  });

  Review _withCurrentAuthor(Review r) => Review(
    id: r.id,
    author: profiles[r.author.id] ?? r.author,
    bookId: r.bookId,
    body: r.body,
    containsSpoilers: r.containsSpoilers,
    createdAt: r.createdAt,
    rating: _ratingOf(r.author.id, r.bookId),
    bookTitle: r.bookTitle,
    coverUrl: r.coverUrl,
  );

  Rating? _ratingOf(String userId, String bookId) =>
      entries.values.where((e) => e.userId == userId && e.book.id == bookId).firstOrNull?.rating;

  // ───────── activity ─────────

  ActivityType _activityFor(ReadingStatus s) => switch (s) {
    ReadingStatus.wantToRead => ActivityType.wantToRead,
    ReadingStatus.reading => ActivityType.started,
    ReadingStatus.finished => ActivityType.finished,
    ReadingStatus.dnf => ActivityType.dnf,
  };

  void _emit(String actorId, ActivityType type, Book book, {Rating? rating, String? excerpt, DateTime? at}) {
    activities.add(
      Activity(
        id: nextId('act'),
        type: type,
        actor: profiles[actorId]!,
        book: book,
        createdAt: at ?? now,
        rating: rating,
        reviewExcerpt: excerpt == null || excerpt.length <= 280 ? excerpt : '${excerpt.substring(0, 280)}…',
      ),
    );
  }

  @override
  Future<FeedPage> feed({FeedCursor? before, int limit = 20}) => _run(() {
    final me = _me;
    final visibleActors = {me, ...follows.where((f) => f.$1 == me).map((f) => f.$2)};
    final sorted = activities.where((a) => visibleActors.contains(a.actor.id)).toList()
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      });
    final start = before == null ? 0 : sorted.indexWhere((a) => a.id == before.id) + 1;
    final page = sorted.skip(start).take(limit).map((a) => _decorate(a, me)).toList();
    final more = start + page.length < sorted.length;
    return FeedPage(page, more && page.isNotEmpty ? FeedCursor(page.last.createdAt, page.last.id) : null);
  });

  Activity _decorate(Activity a, String me) => Activity(
    id: a.id,
    type: a.type,
    actor: profiles[a.actor.id] ?? a.actor,
    book: a.book,
    createdAt: a.createdAt,
    rating: a.rating,
    reviewExcerpt: a.reviewExcerpt,
    likeCount: likes.where((l) => l.$1 == a.id).length,
    likedByMe: likes.contains((a.id, me)),
  );

  @override
  Future<void> like(String activityId) => _run(() => likes.add((activityId, _me)));

  @override
  Future<void> unlike(String activityId) => _run(() => likes.remove((activityId, _me)));
}
