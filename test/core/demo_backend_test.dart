import 'package:bookmarkd/core/demo/demo_backend.dart';
import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/library/domain/rating.dart';
import 'package:bookmarkd/features/library/domain/reading_status.dart';
import 'package:bookmarkd/features/reading/domain/progress_update.dart';
import 'package:bookmarkd/features/social/domain/activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DemoBackend db;
  const catalogBook = Book(
    ids: ExternalIds(googleBooksId: 'g-new'),
    title: 'New Book',
    authors: ['A'],
    pageCount: 200,
  );

  setUp(() async {
    db = DemoBackend(latency: Duration.zero, clock: () => DateTime(2026, 11, 2));
    await db.signIn(email: 'me@example.com', password: 'secret1');
  });

  test('saving the same catalog book twice returns the same stored book', () async {
    final a = await db.save(catalogBook);
    final b = await db.save(catalogBook);
    expect(a.isStored, isTrue);
    expect(b.id, a.id);
  });

  test('adding a book twice keeps a single entry per work', () async {
    final book = await db.save(catalogBook);
    await db.add(book, ReadingStatus.wantToRead);
    await db.add(book, ReadingStatus.reading);
    final library = await db.getLibrary(db.currentUserId!);
    expect(library.where((e) => e.book.id == book.id), hasLength(1));
    expect(library.first.status, ReadingStatus.reading);
  });

  test('library changes appear in my feed, newest first', () async {
    final book = await db.save(catalogBook);
    final entry = await db.add(book, ReadingStatus.reading);
    await db.update(entry.copyWith(rating: () => Rating.fromHalfStars(8)));
    final feed = await db.feed();
    final mine = feed.items.where((a) => a.actor.id == db.currentUserId).map((a) => a.type).toList();
    expect(mine, containsAll([ActivityType.started, ActivityType.rated]));
  });

  test('progress logging records a session and starts want-to-read books', () async {
    final book = await db.save(catalogBook);
    final entry = await db.add(book, ReadingStatus.wantToRead);
    final updated = await db.logProgress(entry.id, ProgressUpdate.page(50, pageCount: 200));
    expect(updated.status, ReadingStatus.reading);
    expect(updated.progressPercent, 25);
    expect((await db.sessions(entry.id)).single.toPage, 50);
  });

  test('cannot follow yourself', () {
    expect(db.follow(db.currentUserId!), throwsA(isA<AppFailure>()));
  });

  test('feed paginates without repeating items', () async {
    final first = await db.feed(limit: 3);
    final second = await db.feed(before: first.next, limit: 3);
    expect(first.items, hasLength(3));
    expect(second.items.map((a) => a.id).toSet().intersection(first.items.map((a) => a.id).toSet()), isEmpty);
  });

  test('likes toggle and are counted once per user', () async {
    final item = (await db.feed()).items.first;
    await db.like(item.id);
    await db.like(item.id);
    expect((await db.feed()).items.first.likeCount, 1);
    await db.unlike(item.id);
    expect((await db.feed()).items.first.likedByMe, isFalse);
  });
}
