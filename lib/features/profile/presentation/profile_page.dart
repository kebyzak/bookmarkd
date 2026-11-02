import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/book_cover.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../../auth/presentation/session_cubit.dart';
import '../../library/domain/library_entry.dart';
import '../../library/domain/reading_status.dart';
import '../../library/presentation/library_cubit.dart';
import '../../reviews/presentation/review_tile.dart';
import '../../statistics/domain/reading_stats.dart';
import '../../statistics/presentation/stats_widgets.dart';
import '../domain/profile.dart';
import 'profile_cubit.dart';

/// The signed-in reader's profile when [userId] is null or theirs;
/// otherwise another reader's.
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
    final libraryEntries = context.select<LibraryCubit, List<LibraryEntry>>((c) => c.state.entries);
    // Own profile reflects the live library and session profile.
    final entries = isSelf ? libraryEntries : state.entries;
    final profile = isSelf ? context.select<SessionCubit, Profile?>((c) => c.profile) : state.profile;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: showBack,
        title: Text(profile?.handle ?? ''),
        actions: [if (isSelf) const _SelfMenu()],
      ),
      body: switch (state.status) {
        LoadStatus.failure => ErrorState(message: state.failure!.message, onRetry: cubit.load),
        LoadStatus.success when profile != null => RefreshIndicator(
          onRefresh: () async {
            await cubit.load();
            if (isSelf && context.mounted) await context.read<LibraryCubit>().reload();
          },
          child: _ProfileContent(profile: profile, state: state, entries: entries, isSelf: isSelf),
        ),
        _ => const SingleChildScrollView(child: ListSkeleton(count: 3, leadingWidth: 72, leadingHeight: 72)),
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
  const _ProfileContent({required this.profile, required this.state, required this.entries, required this.isSelf});
  final Profile profile;
  final ProfileState state;
  final List<LibraryEntry> entries;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final stats = ReadingStats.compute(entries, now: DateTime.now(), goal: profile.readingGoal);
    final finished = entries.where((e) => e.status == ReadingStatus.finished).toList()
      ..sort((a, b) => (b.finishedAt ?? b.addedAt).compareTo(a.finishedAt ?? a.addedAt));
    final favorites = entries.where((e) => e.isFavorite).toList();
    final hidden = !isSelf && profile.isPrivate;

    void open(LibraryEntry e) => context.push(Routes.book(e.book.id!));

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xxl),
      children: [
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
          SectionHeader(title: 'Reviews', subtitle: state.reviews.isEmpty ? null : '${state.reviews.length} written'),
          if (state.reviews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: Text(
                isSelf ? 'Reviews you write will appear here.' : 'No reviews yet.',
                style: context.text.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            )
          else
            ...state.reviews.take(5).map((r) => ReviewTile(key: ValueKey(r.id), review: r, showBook: true)),
          const SectionHeader(title: 'Reading history'),
          if (finished.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: Text(
                'Finished books will appear here.',
                style: context.text.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            )
          else
            ...finished
                .take(20)
                .map(
                  (e) => ListTile(
                    key: ValueKey(e.id),
                    contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    leading: BookCover(book: e.book, width: 32),
                    title: Text(e.book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(e.finishedAt == null ? 'Finished' : 'Finished ${formatDate(e.finishedAt!)}'),
                    onTap: () => open(e),
                  ),
                ),
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

  Future<void> _toggleFollow(BuildContext context) async {
    try {
      await context.read<ProfileCubit>().toggleFollow();
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
            const SizedBox(width: Space.lg),
            _Count(value: state.counts.followers, label: 'Followers'),
            const SizedBox(width: Space.lg),
            _Count(value: state.counts.following, label: 'Following'),
          ],
        ),
        const SizedBox(height: Space.md),
        Text(profile.name, style: context.text.headlineSmall),
        if (profile.displayName?.isNotEmpty ?? false)
          Text(profile.handle, style: context.text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        if (profile.bio?.isNotEmpty ?? false) ...[
          const SizedBox(height: Space.xs),
          Text(profile.bio!, style: context.text.bodyMedium),
        ],
        const SizedBox(height: Space.md),
        SizedBox(
          width: double.infinity,
          child: isSelf
              ? OutlinedButton(onPressed: () => context.push(Routes.editProfile), child: const Text('Edit profile'))
              : state.isFollowing
              ? OutlinedButton(onPressed: () => _toggleFollow(context), child: const Text('Following'))
              : FilledButton(onPressed: () => _toggleFollow(context), child: const Text('Follow')),
        ),
      ],
    ),
  );
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$value $label',
    child: ExcludeSemantics(
      child: Column(
        children: [
          Text(formatCount(value), style: context.text.titleLarge),
          Text(label, style: context.text.bodySmall),
        ],
      ),
    ),
  );
}
