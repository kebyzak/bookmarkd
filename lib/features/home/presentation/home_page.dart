import 'package:bookmarkd/app/di.dart';
import 'package:bookmarkd/app/router/app_router.dart';
import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/utils/formatters.dart';
import 'package:bookmarkd/core/widgets/book_cover.dart';
import 'package:bookmarkd/core/widgets/common.dart';
import 'package:bookmarkd/core/widgets/skeleton.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/auth/presentation/session_cubit.dart';
import 'package:bookmarkd/features/library/domain/library_entry.dart';
import 'package:bookmarkd/features/library/domain/reading_status.dart';
import 'package:bookmarkd/features/library/presentation/library_cubit.dart';
import 'package:bookmarkd/features/reading/presentation/log_sheet.dart';
import 'package:bookmarkd/features/social/presentation/activity_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'home_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (_) => HomeCubit(sl(), sl(), sl()), child: const _HomeView());
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  bool _requested = false;

  Future<void> _load() async {
    final me = context.read<SessionCubit>().profile;
    if (me == null) return;
    await context.read<HomeCubit>().load(myId: me.id, library: context.read<LibraryCubit>().state.entries);
  }

  @override
  Widget build(BuildContext context) {
    final goal = context.select<SessionCubit, int?>((c) => c.profile?.readingGoal);
    final library = context.watch<LibraryCubit>().state;
    final home = context.watch<HomeCubit>().state;

    if (!_requested && library.status == LoadStatus.success) {
      _requested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }

    final now = DateTime.now();
    final entries = library.entries;
    final reading = entries.where((e) => e.status == ReadingStatus.reading).toList()
      ..sort((a, b) => (b.startedAt ?? b.addedAt).compareTo(a.startedAt ?? a.addedAt));
    final finished = entries.where((e) => e.status == ReadingStatus.finished && e.finishedAt?.year == now.year).toList()
      ..sort((a, b) => a.finishedAt!.compareTo(b.finishedAt!));
    final upNext = entries.where((e) => e.status == ReadingStatus.wantToRead).toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    void open(String key) => context.push(Routes.book(key));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            try {
              await context.read<LibraryCubit>().reload();
            } on AppFailure catch (e) {
              if (context.mounted) showMessage(context, e.message);
            }
            if (context.mounted) await _load();
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: Space.xxl),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, 28, Space.xs, Space.xxs),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, d MMMM').format(now),
                            style: context.text.bodySmall?.copyWith(color: context.colors.textSecondary),
                          ),
                          const SizedBox(height: Space.xxs),
                          Semantics(header: true, child: Text('Reading', style: context.text.displaySmall)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: home.unreadNotifications == 0
                          ? 'Notifications'
                          : 'Notifications, ${home.unreadNotifications} new',
                      onPressed: () async {
                        final cubit = context.read<HomeCubit>();
                        await context.push(Routes.notifications);
                        cubit.notificationsSeen();
                      },
                      icon: Badge(
                        isLabelVisible: home.unreadNotifications > 0,
                        backgroundColor: context.colors.accent,
                        label: Text(formatCount(home.unreadNotifications)),
                        child: Icon(Icons.notifications_none_rounded, color: context.colors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              if (library.status == LoadStatus.loading || library.status == LoadStatus.initial)
                const Padding(
                  padding: EdgeInsets.only(top: Space.lg),
                  child: ListSkeleton(count: 2, leadingWidth: 72, leadingHeight: 108),
                )
              else if (library.status == LoadStatus.failure)
                ErrorState(message: library.failure!.message, onRetry: context.read<LibraryCubit>().reload)
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xxs, Space.gutter, 0),
                  child: reading.isEmpty
                      ? _NothingInProgress(hasBooks: entries.isNotEmpty)
                      : Column(
                          children: [for (final e in reading) _ReadingRow(key: ValueKey(e.id), entry: e)],
                        ),
                ),
                _YearShelf(year: now.year, finished: finished, goal: goal),
                if (upNext.isNotEmpty) _UpNext(entries: upNext.take(3).toList()),
              ],
              ..._social(context, home, open),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _social(BuildContext context, HomeState home, void Function(String) open) {
    if (home.status == LoadStatus.loading) {
      return const [SizedBox(height: Space.lg), CoverRowSkeleton()];
    }
    if (home.status == LoadStatus.failure) {
      return [
        Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text("Couldn't load friends and picks · retry"),
          ),
        ),
      ];
    }
    return [
      SectionHeader(title: 'Friends are reading', actionLabel: 'See all', onAction: () => context.push('/activity')),
      if (home.friends.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: SurfaceCard(
            onTap: () => context.go('/search'),
            child: Text('Follow readers to see what they are reading.', style: context.text.bodyMedium),
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Column(
            children: [
              for (final (i, a) in home.friends.indexed) ...[
                if (i > 0) const Divider(),
                ActivityCard(key: ValueKey(a.id), activity: a, compact: true),
              ],
            ],
          ),
        ),
      if (home.recommended.isNotEmpty) ...[
        SectionHeader(
          title: 'Recommended for you',
          subtitle: home.recommendationGenre == null
              ? 'Popular with Bookmarkd readers'
              : 'Popular in ${home.recommendationGenre}, your most-read genre',
        ),
        BookCarousel(books: home.recommended, onTap: (b) => open(b.key)),
      ],
    ];
  }
}

class _NothingInProgress extends StatelessWidget {
  const _NothingInProgress({required this.hasBooks});

  final bool hasBooks;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.go(hasBooks ? '/library' : '/search'),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hasBooks
                  ? 'Nothing in progress. Pick something from your shelf.'
                  : 'Find your first book to start tracking.',
              style: context.text.bodyMedium,
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.colors.textSecondary),
        ],
      ),
    ),
  );
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({super.key, required this.entry});

  final LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final book = entry.book;
    final pages = book.pageCount;
    final percent = entry.progressPercentDisplay;
    final numbers = context.text.bodySmall?.copyWith(
      color: context.colors.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return InkWell(
      onTap: () => context.push(Routes.book(book.id!)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.border)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BookCover(book: book, width: 72),
              SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleLarge?.prose.copyWith(fontSize: 21, height: 1.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.authorLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
                    ),
                    const Spacer(),
                    const SizedBox(height: Space.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      pages != null ? 'p. ${entry.currentPage ?? 0} of $pages' : 'Progress',
                                      style: numbers,
                                    ),
                                  ),
                                  Text(
                                    '$percent%',
                                    style: numbers?.copyWith(
                                      color: context.colors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              AppProgressBar(value: entry.progress, height: 3),
                            ],
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        Semantics(
                          label: 'Log pages for ${book.title}',
                          button: true,
                          excludeSemantics: true,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(60, 44),
                              padding: const EdgeInsets.symmetric(horizontal: Space.md),
                              foregroundColor: context.colors.accent,
                              side: BorderSide(color: context.colors.accent),
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () => showLogSheet(context, entry),
                            child: const Text('Log'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YearShelf extends StatelessWidget {
  const _YearShelf({required this.year, required this.finished, required this.goal});

  final int year;
  final List<LibraryEntry> finished;
  final int? goal;
  static const _maxSlots = 12;

  @override
  Widget build(BuildContext context) {
    final done = finished.length;
    final left = goal == null ? 0 : (goal! - done).clamp(0, goal!);
    final slots = goal == null ? (done == 0 ? 3 : 0) : left.clamp(0, _maxSlots);
    final caption = goal == null
        ? '$done this year'
        : left == 0
        ? '$done of $goal · goal reached'
        : '$done of $goal · $left to go';

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Semantics(header: true, child: Text('Your $year', style: context.text.titleLarge)),
              ),
              if (goal == null)
                TextButton(onPressed: () => context.push(Routes.editProfile), child: Text('$caption · Set a goal'))
              else
                Text(
                  caption,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Semantics(
            label: 'Your $year shelf: $caption',
            child: Container(
              height: 132,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.colors.textPrimary, width: 2)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final e in finished) _Spine(entry: e),
                    for (var i = 0; i < slots; i++) _Slot(height: 100.0 + (i * 7) % 22),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Spine extends StatelessWidget {
  const _Spine({required this.entry});

  final LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final book = entry.book;
    final width = ((book.pageCount ?? 300) / 30).clamp(20.0, 34.0);
    final height = 100.0 + book.title.length * 7 % 27;
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: Tooltip(
        message: book.title,
        child: GestureDetector(
          onTap: () => context.push(Routes.book(book.id!)),
          child: Container(
            width: width,
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: coverTone(book.title),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            ),
            child: RotatedBox(
              quarterTurns: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                child: Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(fontFamily: AppTheme.serif, fontSize: 11, color: onCoverTone),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 3),
    child: CustomPaint(size: Size(24, height), painter: _DashedSlotPainter(context.colors.starEmpty)),
  );
}

class _DashedSlotPainter extends CustomPainter {
  const _DashedSlotPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 3.0;
    for (var y = size.height; y > 0; y -= dash * 2) {
      canvas.drawLine(Offset(0.5, y), Offset(0.5, (y - dash).clamp(0, size.height)), paint);
      canvas.drawLine(Offset(size.width - 0.5, y), Offset(size.width - 0.5, (y - dash).clamp(0, size.height)), paint);
    }
    for (var x = 0.0; x < size.width; x += dash * 2) {
      canvas.drawLine(Offset(x, 0.5), Offset((x + dash).clamp(0, size.width), 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedSlotPainter old) => old.color != color;
}

class _UpNext extends StatelessWidget {
  const _UpNext({required this.entries});

  final List<LibraryEntry> entries;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text('Up next', style: context.text.titleLarge)),
        const SizedBox(height: Space.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: SizedBox(
                  width: 96,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BookCover(book: e.book, width: 56, onTap: () => context.push(Routes.book(e.book.id!))),
                      const SizedBox(height: 6),
                      Text(
                        e.book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(color: context.colors.textSecondary, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
