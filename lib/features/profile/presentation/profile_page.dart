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
import 'package:bookmarkd/features/profile/domain/profile.dart';
import 'package:bookmarkd/features/reviews/presentation/review_tile.dart';
import 'package:bookmarkd/features/statistics/domain/reading_stats.dart';
import 'package:bookmarkd/features/statistics/presentation/stats_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'profile_cubit.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context) {
    final me = context.select<SessionCubit, String?>((c) => c.profile?.id);
    if (me == null) return const Scaffold();
    final id = userId ?? me;
    return BlocProvider(
      key: ValueKey(id),
      create: (_) =>
          ProfileCubit(userId: id, isSelf: id == me, profiles: sl(), social: sl(), library: sl(), reviews: sl())
            ..load(),
      child: _ProfileView(isSelf: id == me, showBack: userId != null),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({required this.isSelf, required this.showBack});

  final bool isSelf;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProfileCubit>().state;
    final cubit = context.read<ProfileCubit>();
    final library = context.select<LibraryCubit, Map<String, LibraryEntry>>((c) => c.state.byId);
    final entries = isSelf ? library.values.toList() : state.entries;
    final profile = isSelf ? context.select<SessionCubit, Profile?>((c) => c.profile) : state.profile;

    final tab = isSelf && !showBack;
    return Scaffold(
      appBar: tab
          ? null
          : AppBar(
              automaticallyImplyLeading: showBack,
              title: Text(profile?.handle ?? ''),
              actions: [if (isSelf) const _SelfMenu()],
            ),
      body: switch (state.status) {
        LoadStatus.failure => SafeArea(
          child: ErrorState(message: state.failure!.message, onRetry: cubit.load),
        ),
        LoadStatus.success when profile != null => RefreshIndicator(
          onRefresh: () async {
            await cubit.load();
            if (!isSelf || !context.mounted) return;
            try {
              await context.read<LibraryCubit>().reload();
            } on AppFailure catch (e) {
              if (context.mounted) showMessage(context, e.message);
            }
          },
          child: _ProfileContent(profile: profile, state: state, entries: entries, isSelf: isSelf, tab: tab),
        ),
        _ => const SafeArea(
          child: SingleChildScrollView(child: ListSkeleton(count: 3, leadingWidth: 72, leadingHeight: 72)),
        ),
      },
    );
  }
}

class _SelfMenu extends StatelessWidget {
  const _SelfMenu();

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'More',
    icon: const Icon(Icons.more_horiz_rounded),
    onSelected: (v) async {
      if (v == 'edit') context.push(Routes.editProfile);
      if (v == 'signout') {
        final ok = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text('Sign out?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Sign out')),
            ],
          ),
        );
        if (ok == true && context.mounted) {
          try {
            await context.read<SessionCubit>().signOut();
          } catch (e) {
            if (context.mounted) showMessage(context, AppFailure.from(e).message);
          }
        }
      }
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'edit', child: Text('Edit profile')),
      PopupMenuItem(value: 'signout', child: Text('Sign out')),
    ],
  );
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.state,
    required this.entries,
    required this.isSelf,
    required this.tab,
  });

  final Profile profile;
  final ProfileState state;
  final List<LibraryEntry> entries;
  final bool isSelf;
  final bool tab;

  @override
  Widget build(BuildContext context) {
    final stats = ReadingStats.compute(entries, now: DateTime.now(), goal: profile.readingGoal);
    final finished = entries.where((e) => e.status == ReadingStatus.finished).toList()
      ..sort(
        (a, b) => switch ((a.finishedAt, b.finishedAt)) {
          (final x?, final y?) => y.compareTo(x),
          (_?, null) => -1,
          (null, _?) => 1,
          (null, null) => b.addedAt.compareTo(a.addedAt),
        },
      );
    final favorites = entries.where((e) => e.isFavorite).toList();
    final reading = entries.where((e) => e.status == ReadingStatus.reading).toList()
      ..sort((a, b) => (b.startedAt ?? b.addedAt).compareTo(a.startedAt ?? a.addedAt));
    final hidden = !isSelf && profile.isPrivate;

    void open(LibraryEntry e) => context.push(Routes.book(e.book.id!));

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xxl),
      children: [
        if (tab)
          Padding(
            padding: EdgeInsets.fromLTRB(Space.gutter, MediaQuery.paddingOf(context).top + 28, Space.xs, Space.md),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(header: true, child: Text('You', style: context.text.displaySmall)),
                ),
                const _SelfMenu(),
              ],
            ),
          ),
        _Header(profile: profile, state: state, isSelf: isSelf),
        if (hidden)
          const EmptyState(icon: Icons.lock_outline_rounded, title: 'This profile is private')
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
            child: Column(
              children: [
                if (profile.readingGoal != null) ...[GoalCard(stats: stats), const SizedBox(height: Space.sm)],
                StatsGrid(stats: stats),
              ],
            ),
          ),
          if (reading.isNotEmpty) ...[
            const SectionHeader(title: 'Currently reading'),
            for (final (i, e) in reading.indexed) ...[
              if (i > 0) const Divider(indent: Space.gutter, endIndent: Space.gutter),
              _ReadingProgressTile(key: ValueKey(e.id), entry: e, onTap: () => open(e)),
            ],
          ],
          if (finished.isNotEmpty) ...[
            const SectionHeader(title: 'Recently finished'),
            BookCarousel(
              books: finished.take(12).map((e) => e.book).toList(),
              onTap: (b) => open(finished.firstWhere((e) => e.book == b)),
            ),
          ],
          if (favorites.isNotEmpty) ...[
            const SectionHeader(title: 'Favorites'),
            BookCarousel(
              books: favorites.map((e) => e.book).toList(),
              onTap: (b) => open(favorites.firstWhere((e) => e.book == b)),
            ),
          ],
          SectionHeader(title: 'Reviews', subtitle: state.reviewCount == 0 ? null : '${state.reviewCount} written'),
          if (state.reviews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: Text(
                isSelf ? 'Reviews you write will appear here.' : 'No reviews yet.',
                style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
              ),
            )
          else
            for (final (i, r) in state.reviews.indexed) ...[
              if (i > 0) const Divider(indent: Space.gutter, endIndent: Space.gutter),
              ReviewTile(key: ValueKey(r.id), review: r, showBook: true),
            ],
          SectionHeader(
            title: 'Reading history',
            actionLabel: isSelf ? 'Add a past read' : null,
            onAction: () => context.go('/search'),
          ),
          if (finished.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: Text(
                isSelf
                    ? 'Finished books will appear here. Mark a book Finished to pick the date you read it.'
                    : 'Finished books will appear here.',
                style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
              ),
            )
          else
            for (final (i, e) in finished.take(20).indexed) ...[
              if (i > 0) const Divider(indent: Space.gutter, endIndent: Space.gutter),
              ListTile(
                key: ValueKey(e.id),
                contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                leading: BookCover(book: e.book, width: 32),
                title: Text(
                  e.book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleMedium?.prose.copyWith(fontSize: 17),
                ),
                subtitle: Text(
                  e.finishedAt == null ? 'Read some time ago' : 'Finished ${formatDate(e.finishedAt!)}',
                  style: context.text.bodySmall?.copyWith(color: context.colors.textSecondary),
                ),
                onTap: () => open(e),
              ),
            ],
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.state, required this.isSelf});

  final Profile profile;
  final ProfileState state;
  final bool isSelf;

  bool get hidden => !isSelf && profile.isPrivate;

  Future<void> _openList(BuildContext context, String route) async {
    await context.push(route);
    if (context.mounted) await context.read<ProfileCubit>().load();
  }

  Future<void> _toggleFollow(BuildContext context, {bool offerUndo = true}) async {
    final cubit = context.read<ProfileCubit>();
    final unfollowing = cubit.state.isFollowing;
    try {
      await cubit.toggleFollow();
      if (unfollowing && offerUndo && context.mounted) {
        showMessage(
          context,
          'Unfollowed ${profile.handle}',
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (context.mounted) _toggleFollow(context, offerUndo: false);
            },
          ),
        );
      }
    } catch (e) {
      if (context.mounted) showMessage(context, AppFailure.from(e).message);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppAvatar(profile: profile, size: 76),
            const SizedBox(width: Space.md),
            _Count(
              value: state.counts.followers,
              label: 'Followers',
              onTap: hidden ? null : () => _openList(context, Routes.followers(profile.id)),
            ),
            _Count(
              value: state.counts.following,
              label: 'Following',
              onTap: hidden ? null : () => _openList(context, Routes.following(profile.id)),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        Text(profile.name, style: context.text.headlineMedium),
        if (profile.displayName?.isNotEmpty ?? false)
          Text(profile.handle, style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary)),
        if (profile.bio?.isNotEmpty ?? false) ...[
          const SizedBox(height: Space.xs),
          Text(profile.bio!, style: context.text.bodyMedium),
        ],
        const SizedBox(height: Space.md),
        SizedBox(
          width: double.infinity,
          child: isSelf
              ? OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: context.colors.accentSoft,
                    foregroundColor: context.colors.accent,
                    side: BorderSide(color: context.colors.accentSoft),
                  ),
                  onPressed: () => context.push(Routes.editProfile),
                  child: const Text('Edit profile'),
                )
              : state.isFollowing
              ? OutlinedButton(onPressed: () => _toggleFollow(context), child: const Text('Following'))
              : FilledButton(onPressed: () => _toggleFollow(context), child: const Text('Follow')),
        ),
      ],
    ),
  );
}

class _ReadingProgressTile extends StatelessWidget {
  const _ReadingProgressTile({super.key, required this.entry, required this.onTap});

  final LibraryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.sm),
      child: Row(
        children: [
          BookCover(book: entry.book, width: 44),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleMedium?.prose.copyWith(fontSize: 17),
                ),
                Text(
                  entry.book.authorLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: context.colors.textSecondary),
                ),
                const SizedBox(height: Space.xs),
                Semantics(
                  label: entry.progressLabel,
                  child: ExcludeSemantics(child: AppProgressBar(value: entry.progress, height: 4)),
                ),
                const SizedBox(height: Space.xxs),
                ExcludeSemantics(
                  child: Text(
                    entry.progressLabel,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label, this.onTap});

  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$value $label',
    button: onTap != null,
    onTap: onTap,
    child: ExcludeSemantics(
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.card,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.xxs),
          child: Column(
            children: [
              Text(formatCount(value), style: context.text.titleLarge),
              Text(label, style: context.text.bodySmall),
            ],
          ),
        ),
      ),
    ),
  );
}
