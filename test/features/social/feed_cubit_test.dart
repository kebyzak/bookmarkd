import 'package:bookmarkd/core/demo/demo_backend.dart';
import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/social/presentation/feed_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class FlakyLikes extends DemoBackend {
  FlakyLikes() : super(latency: Duration.zero, clock: () => DateTime(2026, 11, 2));
  bool fail = false;

  @override
  Future<void> like(String activityId) => fail ? Future.error(const AppFailure.network()) : super.like(activityId);
}

void main() {
  late FlakyLikes db;

  setUp(() async {
    db = FlakyLikes();
    await db.signIn(email: 'me@example.com', password: 'secret1');
  });

  test('loads pages until the feed is exhausted, without duplicates', () async {
    final cubit = FeedCubit(db, pageSize: 4);
    await cubit.refresh();
    expect(cubit.state.status, LoadStatus.success);
    expect(cubit.state.items, hasLength(4));
    while (cubit.state.hasMore) {
      await cubit.loadMore();
    }
    final ids = cubit.state.items.map((a) => a.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids.length, (await db.feed(limit: 100)).items.length);
  });

  test('like is optimistic and rolls back on failure', () async {
    final cubit = FeedCubit(db);
    await cubit.refresh();
    final first = cubit.state.items.first;

    await cubit.toggleLike(first);
    expect(cubit.state.items.first.likedByMe, isTrue);
    expect(cubit.state.items.first.likeCount, first.likeCount + 1);

    db.fail = true;
    final second = cubit.state.items[1];
    await expectLater(cubit.toggleLike(second), throwsA(isA<AppFailure>()));
    expect(cubit.state.items[1].likedByMe, isFalse);
  });

  test('refresh replaces items with the newest page', () async {
    final cubit = FeedCubit(db, pageSize: 2);
    await cubit.refresh();
    await cubit.loadMore();
    await cubit.refresh();
    expect(cubit.state.items, hasLength(2));
  });
}
