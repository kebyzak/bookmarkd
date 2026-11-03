import 'package:bookmarkd/app/di.dart';
import 'package:bookmarkd/app/router/app_router.dart';
import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/utils/formatters.dart';
import 'package:bookmarkd/core/widgets/common.dart';
import 'package:bookmarkd/core/widgets/skeleton.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/auth/presentation/session_cubit.dart';
import 'package:bookmarkd/features/profile/domain/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'readers_cubit.dart';

enum ReaderList { followers, following, notifications }

class ReadersPage extends StatelessWidget {
  const ReadersPage({super.key, required this.list, this.userId});

  final ReaderList list;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final social = sl<SocialRepository>();
    Future<List<ReaderLink>> fetch() async {
      switch (list) {
        case ReaderList.followers:
          return social.followers(userId!);
        case ReaderList.following:
          return social.following(userId!);
        case ReaderList.notifications:
          final links = await social.followNotifications();
          social.markNotificationsRead().ignore();
          return links;
      }
    }

    return BlocProvider(
      create: (_) => ReadersCubit(fetch, social)..load(),
      child: _ReadersView(list: list),
    );
  }
}

class _ReadersView extends StatelessWidget {
  const _ReadersView({required this.list});

  final ReaderList list;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReadersCubit>().state;
    final cubit = context.read<ReadersCubit>();
    final me = context.select<SessionCubit, String?>((c) => c.profile?.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (list) {
          ReaderList.followers => 'Followers',
          ReaderList.following => 'Following',
          ReaderList.notifications => 'Notifications',
        }),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: cubit.load,
          child: switch (state.status) {
            LoadStatus.initial || LoadStatus.loading => const SingleChildScrollView(
              child: ListSkeleton(count: 6, leadingWidth: 44, leadingHeight: 44),
            ),
            LoadStatus.failure => _Scrollable(
              child: ErrorState(message: state.failure!.message, onRetry: cubit.load),
            ),
            LoadStatus.success when state.links.isEmpty => _Scrollable(
              child: switch (list) {
                ReaderList.followers => const EmptyState(icon: Icons.people_outline_rounded, title: 'No followers yet'),
                ReaderList.following => const EmptyState(
                  icon: Icons.person_add_alt_outlined,
                  title: 'Not following anyone yet',
                ),
                ReaderList.notifications => const EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'Nothing new',
                  message: "You'll see here when someone starts following you.",
                ),
              },
            ),
            LoadStatus.success => ListView.builder(
              itemCount: state.links.length,
              itemBuilder: (_, i) {
                final link = state.links[i];
                return ReaderTile(
                  key: ValueKey(link.profile.id),
                  link: link,
                  isMe: link.profile.id == me,
                  notice: list == ReaderList.notifications,
                );
              },
            ),
          },
        ),
      ),
    );
  }
}

class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [SliverFillRemaining(hasScrollBody: false, child: Center(child: child))],
  );
}

class ReaderTile extends StatelessWidget {
  const ReaderTile({super.key, required this.link, required this.isMe, this.notice = false});

  final ReaderLink link;
  final bool isMe;
  final bool notice;

  static const _compact = Size(0, 36);
  static const _compactPadding = EdgeInsets.symmetric(horizontal: Space.md);

  Future<void> _toggle(BuildContext context) async {
    try {
      await context.read<ReadersCubit>().toggleFollow(link.profile.id);
    } catch (e) {
      if (context.mounted) showMessage(context, AppFailure.from(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = link.profile;
    final c = context.colors;
    final subtitle = notice ? 'started following you · ${relativeTime(link.at)}' : p.handle;
    return ListTile(
      tileColor: link.unread ? c.accentSoft : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      leading: AppAvatar(profile: p, size: 44),
      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
      trailing: isMe
          ? null
          : link.following
          ? OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: _compact, padding: _compactPadding),
              onPressed: () => _toggle(context),
              child: const Text('Following'),
            )
          : FilledButton(
              style: FilledButton.styleFrom(minimumSize: _compact, padding: _compactPadding),
              onPressed: () => _toggle(context),
              child: Text(notice ? 'Follow back' : 'Follow'),
            ),
      onTap: () => context.push(Routes.user(p.id)),
    );
  }
}
