import 'package:bloc_test/bloc_test.dart';
import 'package:bookmarkd/core/demo/demo_backend.dart';
import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/library/domain/library_entry.dart';
import 'package:bookmarkd/features/library/domain/rating.dart';
import 'package:bookmarkd/features/library/domain/reading_status.dart';
import 'package:bookmarkd/features/library/presentation/library_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Demo backend whose library writes fail on demand.
class FlakyBackend extends DemoBackend {
  FlakyBackend() : super(latency: Duration.zero, clock: () => DateTime(2026, 11, 2));
  bool fail = false;

  @override
  Future<LibraryEntry> update(LibraryEntry entry) =>
      fail ? Future.error(const AppFailure.network()) : super.update(entry);

  @override
  Future<void> remove(String entryId) => fail ? Future.error(const AppFailure.network()) : super.remove(entryId);
}

void main() {
  late FlakyBackend db;
  late LibraryCubit cubit;
  const catalogBook = Book(
    ids: ExternalIds(googleBooksId: 'g-x'),
    title: 'X',
    authors: ['Y'],
  );

  setUp(() async {
    db = FlakyBackend();
    await db.signIn(email: 'me@example.com', password: 'secret1');
    cubit = LibraryCubit(db, db, clock: () => DateTime(2026, 11, 2));
    await cubit.load(db.currentUserId!);
  });

  tearDown(() => cubit.close());

  test('loads an empty library for a new reader', () {
    expect(cubit.state.status, LoadStatus.success);
    expect(cubit.state.entries, isEmpty);
  });

  test('adding a catalog book stores it and finds it again by external id', () async {
    await cubit.add(catalogBook, ReadingStatus.reading);
    expect(cubit.state.entryFor(catalogBook)?.status, ReadingStatus.reading);
  });

  test('rating is applied optimistically and kept on success', () async {
    final entry = await cubit.add(catalogBook, ReadingStatus.finished);
    final future = cubit.rate(entry, Rating.fromHalfStars(9));
    expect(cubit.state.entryFor(catalogBook)?.rating?.halfStars, 9);
    await future;
    expect(cubit.state.entryFor(catalogBook)?.rating?.halfStars, 9);
  });

  test('a failed status change rolls back and reports the failure', () async {
    final entry = await cubit.add(catalogBook, ReadingStatus.wantToRead);
    db.fail = true;
    await expectLater(cubit.setStatus(entry, ReadingStatus.finished), throwsA(isA<AppFailure>()));
    expect(cubit.state.entryFor(catalogBook)?.status, ReadingStatus.wantToRead);
  });

  test('a failed removal restores the entry', () async {
    final entry = await cubit.add(catalogBook, ReadingStatus.wantToRead);
    db.fail = true;
    await expectLater(cubit.remove(entry), throwsA(isA<AppFailure>()));
    expect(cubit.state.entryFor(catalogBook), isNotNull);
  });

  blocTest<LibraryCubit, LibraryState>(
    'clear empties the library on sign-out',
    build: () => cubit,
    act: (c) => c.clear(),
    expect: () => [isA<LibraryState>().having((s) => s.entries, 'entries', isEmpty)],
  );
}
