import 'package:bookmarkd/app/di.dart';
import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/widgets/skeleton.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/social/domain/activity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'activity_card.dart';
import 'feed_cubit.dart';

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (_) => FeedCubit(sl())..refresh(), child: const _ActivityView());
}

class _ActivityView extends StatelessWidget {
  const _ActivityView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FeedCubit>().state;
    final cubit = context.read<FeedCubit>();

    Future<void> like(Activity a) async {
      try {
        await cubit.toggleLike(a);
      } catch (e) {
        if (context.mounted) showMessage(context, AppFailure.from(e).message);
      }
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity', style: context.text.headlineMedium),
          Text('You and the readers you follow', style: context.text.bodySmall),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: cubit.refresh,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 500) cubit.loadMore();
              return false;
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: header),
                ...switch (state.status) {
                  LoadStatus.initial || LoadStatus.loading => [
                    const SliverToBoxAdapter(child: ListSkeleton(count: 6, leadingWidth: 40, leadingHeight: 40)),
                  ],
                  LoadStatus.failure => [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: ErrorState(message: state.failure!.message, onRetry: cubit.refresh),
                    ),
                  ],
                  LoadStatus.success when state.items.isEmpty => [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.forum_outlined,
                        title: 'Quiet in here',
                        message: 'Follow other readers to see what they start, finish and review.',
                        action: FilledButton(onPressed: () => context.go('/search'), child: const Text('Find readers')),
                      ),
                    ),
                  ],
                  LoadStatus.success => [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                      sliver: SliverList.separated(
                        itemCount: state.items.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (_, i) => ActivityCard(
                          key: ValueKey(state.items[i].id),
                          activity: state.items[i],
                          onLike: () => like(state.items[i]),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(Space.lg),
                        child: Center(
                          child: state.loadingMore
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                              : state.loadMoreFailed
                              ? TextButton.icon(
                                  onPressed: () => cubit.loadMore(retry: true),
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  label: const Text("Couldn't load more · Retry"),
                                )
                              : state.hasMore
                              ? const SizedBox.shrink()
                              : Text("You're all caught up", style: context.text.bodySmall),
                        ),
                      ),
                    ),
                  ],
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}
