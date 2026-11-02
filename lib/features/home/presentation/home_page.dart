import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/book_cover.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../../auth/presentation/session_cubit.dart';
import '../../library/domain/library_entry.dart';
import '../../library/domain/reading_status.dart';
import '../../library/presentation/library_cubit.dart';
import '../../social/presentation/activity_card.dart';
import '../../statistics/domain/reading_stats.dart';
import '../../statistics/presentation/stats_widgets.dart';
import 'home_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(create: (_) => HomeCubit(sl(), sl()), child: const _HomeView());
}

class _HomeView extends StatefulWidget {
  const _HomeView();
  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  bool _requested = false;

  /// Kept across rebuilds so the carousel stays on the book the reader swiped to.
  final _readingPages = PageController(viewportFraction: 0.9);

  @override
  void dispose() {
    _readingPages.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final me = context.read<SessionCubit>().profile;
    if (me == null) return;
    await context.read<HomeCubit>().load(myId: me.id, library: context.read<LibraryCubit>().state.entries);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.select<SessionCubit, String>((c) => c.profile?.name ?? '');
    final goal = context.select<SessionCubit, int?>((c) => c.profile?.readingGoal);
    final library = context.watch<LibraryCubit>().state;
    final home = context.watch<HomeCubit>().state;

    // Recommendations depend on the shelf, so wait for it once.
    if (!_requested && library.status == LoadStatus.success) {
      _requested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }

    final entries = library.entries;
    final reading = entries.where((e) => e.status == ReadingStatus.reading).toList()
      ..sort((a, b) => (b.startedAt ?? b.addedAt).compareTo(a.startedAt ?? a.addedAt));
    final recent = [...entries]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final stats = ReadingStats.compute(entries, now: DateTime.now(), goal: goal);
    void open(String key) => context.push(Routes.book(key));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await context.read<LibraryCubit>().reload();
            if (context.mounted) await _load();
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: Space.xxl),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting(), style: context.text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                    Text(profile, style: context.text.headlineMedium),
                  ],
                ),
              ),
              if (library.status == LoadStatus.loading || library.status == LoadStatus.initial)
                const Padding(
                  padding: EdgeInsets.only(top: Space.lg),
                  child: ListSkeleton(count: 2, leadingWidth: 80, leadingHeight: 120),
                )
              else if (library.status == LoadStatus.failure)
                ErrorState(message: library.failure!.message, onRetry: context.read<LibraryCubit>().reload)
              else ...[
                const SectionHeader(title: 'Currently reading'),
                if (reading.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    child: SurfaceCard(
                      onTap: () => context.go(entries.isEmpty ? '/search' : '/library'),
                      child: Row(
                        children: [
                          const Icon(Icons.menu_book_outlined, color: AppColors.accent),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Text(
                              entries.isEmpty
                                  ? 'Find your first book to start tracking.'
                                  : 'Nothing in progress. Pick something from your shelf.',
                              style: context.text.bodyMedium,
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 190 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4),
                    child: reading.length == 1
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                            child: _CurrentlyReadingCard(key: ValueKey(reading[0].id), entry: reading[0]),
                          )
                        : PageView.builder(
                            controller: _readingPages,
                            padEnds: false,
                            itemCount: reading.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.only(left: Space.gutter, right: Space.xs),
                              child: _CurrentlyReadingCard(key: ValueKey(reading[i].id), entry: reading[i]),
                            ),
                          ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
                  child: GoalCard(stats: stats, onSetGoal: () => context.push(Routes.editProfile)),
                ),
                if (recent.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Recently added',
                    actionLabel: 'Library',
                    onAction: () => context.go('/library'),
                  ),
                  BookCarousel(books: recent.take(12).map((e) => e.book).toList(), onTap: (b) => open(b.id!)),
                ],
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
      SectionHeader(title: 'Friends are reading', actionLabel: 'See all', onAction: () => context.go('/activity')),
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
            children: home.friends
                .map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: Space.xs),
                    child: ActivityCard(key: ValueKey(a.id), activity: a, compact: true),
                  ),
                )
                .toList(),
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

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Reading late';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

class _CurrentlyReadingCard extends StatelessWidget {
  const _CurrentlyReadingCard({super.key, required this.entry});
  final LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final pages = entry.book.pageCount;
    final detail = pages != null ? 'Page ${entry.currentPage ?? 0} of $pages' : '${entry.progressPercentDisplay}% read';
    return SurfaceCard(
      onTap: () => context.push(Routes.book(entry.book.id!)),
      child: Row(
        children: [
          BookCover(book: entry.book, width: 96),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                Text(
                  entry.book.authorLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall,
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(child: Text(detail, style: context.text.labelMedium)),
                    Text(
                      '${entry.progressPercentDisplay}%',
                      style: context.text.labelMedium?.copyWith(color: AppColors.accent),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                AppProgressBar(value: entry.progress),
                const SizedBox(height: Space.sm),
                SizedBox(
                  height: 40,
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: () => context.push(Routes.progress(entry.book.id!)),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Update progress'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
