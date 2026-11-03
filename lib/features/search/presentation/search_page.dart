import 'dart:async';

import 'package:bookmarkd/app/di.dart';
import 'package:bookmarkd/app/router/app_router.dart';
import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/widgets/book_cover.dart';
import 'package:bookmarkd/core/widgets/common.dart';
import 'package:bookmarkd/core/widgets/skeleton.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/books/domain/catalog_query.dart';
import 'package:bookmarkd/features/books/presentation/widgets/book_list_tile.dart';
import 'package:bookmarkd/features/profile/domain/profile.dart';
import 'package:bookmarkd/features/social/presentation/activity_card.dart';
import 'package:bookmarkd/features/social/presentation/feed_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'discover_cubit.dart';
import 'search_cubit.dart';

enum _Scope { books, readers }

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => SearchCubit(sl())),
      BlocProvider(create: (_) => DiscoverCubit(sl(), sl())..load()),
      BlocProvider(create: (_) => FeedCubit(sl(), pageSize: 4)..refresh()),
    ],
    child: const _SearchView(),
  );
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _controller = TextEditingController();
  _Scope _scope = _Scope.books;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open(Book book) async {
    await context.push(Routes.book(book.key));
    if (mounted) context.read<DiscoverCubit>().refreshRecent();
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchCubit>().state;
    final hasQuery = _controller.text.trim().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 28, Space.gutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text('Discover', style: context.text.displaySmall)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _controller,
                    onChanged: (v) {
                      setState(() {});
                      if (_scope == _Scope.books) context.read<SearchCubit>().queryChanged(v);
                    },
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      if (_scope == _Scope.books) context.read<SearchCubit>().submitted();
                    },
                    decoration: InputDecoration(
                      hintText: _scope == _Scope.books ? 'Title, author or ISBN' : 'Find readers by username',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: hasQuery
                          ? IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _controller.clear();
                                context.read<SearchCubit>().queryChanged('');
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  _ScopeSwitch(
                    scope: _scope,
                    onChanged: (scope) {
                      setState(() => _scope = scope);
                      if (scope == _Scope.books) context.read<SearchCubit>().queryChanged(_controller.text);
                    },
                  ),
                  if (_scope == _Scope.books && hasQuery) ...[
                    const SizedBox(height: Space.sm),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final mode in SearchMode.values) ...[
                            ChoiceChip(
                              label: Text(mode.label),
                              selected: search.mode == mode,
                              onSelected: (_) => context.read<SearchCubit>().modeChanged(mode),
                            ),
                            const SizedBox(width: Space.xs),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Space.xs),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.fast,
                switchInCurve: Motion.curve,
                switchOutCurve: Motion.curve,
                child: switch ((_scope, hasQuery)) {
                  (_Scope.readers, _) => _ReaderResults(key: const ValueKey('readers'), query: _controller.text),
                  (_Scope.books, false) => _Discover(
                    key: const ValueKey('discover'),
                    onOpen: _open,
                    onFindReaders: () => setState(() => _scope = _Scope.readers),
                  ),
                  (_Scope.books, true) => _BookResults(key: const ValueKey('results'), state: search, onOpen: _open),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookResults extends StatelessWidget {
  const _BookResults({super.key, required this.state, required this.onOpen});

  final SearchState state;
  final ValueChanged<Book> onOpen;

  @override
  Widget build(BuildContext context) => switch (state.status) {
    LoadStatus.initial => const SizedBox.shrink(),
    LoadStatus.loading when state.results.isEmpty => const SingleChildScrollView(child: ListSkeleton(count: 6)),
    LoadStatus.loading => Stack(
      children: [
        _list(context),
        const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2)),
      ],
    ),
    LoadStatus.failure => ErrorState(message: state.failure!.message, onRetry: context.read<SearchCubit>().retry),
    LoadStatus.success when state.results.isEmpty => EmptyState(
      icon: Icons.search_off_rounded,
      title: 'No books found',
      message: state.mode == SearchMode.any
          ? 'Try a different spelling, or search by author or ISBN.'
          : 'Try searching across all fields.',
    ),
    LoadStatus.success => _list(context),
  };

  Widget _list(BuildContext context) => NotificationListener<ScrollNotification>(
    onNotification: (n) {
      if (n.metrics.extentAfter < 400) context.read<SearchCubit>().loadMore();
      return false;
    },
    child: ListView.builder(
      key: ValueKey('${state.text}|${state.mode}'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: state.results.length + (state.hasMore && state.status == LoadStatus.success ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == state.results.length) {
          return Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Center(
              child: state.loadMoreFailed
                  ? TextButton.icon(
                      onPressed: () => context.read<SearchCubit>().loadMore(retry: true),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text("Couldn't load more · Retry"),
                    )
                  : const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        final book = state.results[i];
        return BookListTile(key: ValueKey(book.key), book: book, onTap: () => onOpen(book));
      },
    ),
  );
}

class _Discover extends StatelessWidget {
  const _Discover({super.key, required this.onOpen, required this.onFindReaders});

  final ValueChanged<Book> onOpen;
  final VoidCallback onFindReaders;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DiscoverCubit>().state;
    final cubit = context.read<DiscoverCubit>();
    if (state.status == LoadStatus.loading) {
      return const SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: Space.lg),
            CoverRowSkeleton(),
            SizedBox(height: Space.lg),
            CoverRowSkeleton(),
          ],
        ),
      );
    }
    final noCommunity = state.trending.isEmpty && state.popular.isEmpty;
    final feed = context.read<FeedCubit>();
    return RefreshIndicator(
      onRefresh: () => Future.wait([cubit.load(), feed.refresh()]),
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: Space.xl),
        children: [
          _FriendsLately(onFindReaders: onFindReaders),
          if (state.trending.isNotEmpty) ...[
            const SectionHeader(title: 'On shelves this week'),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                itemCount: state.trending.length,
                separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                itemBuilder: (_, i) {
                  final book = state.trending[i];
                  return BookCover(key: ValueKey(book.key), book: book, width: 72, onTap: () => onOpen(book));
                },
              ),
            ),
          ],
          if (state.recent.isNotEmpty) ...[
            SectionHeader(title: 'Recently viewed', actionLabel: 'Clear', onAction: cubit.clearRecent),
            BookCarousel(books: state.recent, onTap: onOpen, coverWidth: 88),
          ],
          if (state.status == LoadStatus.failure)
            ErrorState(message: state.failure!.message, onRetry: cubit.load)
          else if (noCommunity)
            const EmptyState(
              icon: Icons.local_library_outlined,
              title: 'Nothing trending yet',
              message: 'Trending and popular books come from what readers here add. Search above to start your shelf.',
            )
          else ...[
            if (state.popular.isNotEmpty) ...[
              const SectionHeader(title: 'Popular on Bookmarkd', subtitle: 'On the most shelves'),
              BookCarousel(books: state.popular, onTap: onOpen),
            ],
            if (state.genres.isNotEmpty) ...[
              const SectionHeader(title: 'Browse by genre'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: state.genres
                      .map(
                        (g) => ChoiceChip(
                          label: Text(g),
                          selected: state.genre == g,
                          onSelected: (on) => cubit.selectGenre(on ? g : null),
                        ),
                      )
                      .toList(),
                ),
              ),
              if (state.genre != null) ...[
                const SizedBox(height: Space.sm),
                ...state.genreBooks.map((b) => BookListTile(key: ValueKey(b.key), book: b, onTap: () => onOpen(b))),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _ScopeSwitch extends StatelessWidget {
  const _ScopeSwitch({required this.scope, required this.onChanged});

  final _Scope scope;
  final ValueChanged<_Scope> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.skeleton, borderRadius: const BorderRadius.all(Radius.circular(10))),
      child: Row(
        children: [
          for (final (s, label) in [(_Scope.books, 'Books'), (_Scope.readers, 'Readers')])
            Expanded(
              child: Semantics(
                selected: s == scope,
                button: true,
                child: Material(
                  color: s == scope ? c.surface : Colors.transparent,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  child: InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    onTap: s == scope ? null : () => onChanged(s),
                    child: SizedBox(
                      height: 40,
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: s == scope ? FontWeight.w600 : FontWeight.w500,
                            color: s == scope ? c.textPrimary : c.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FriendsLately extends StatelessWidget {
  const _FriendsLately({required this.onFindReaders});

  final VoidCallback onFindReaders;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FeedCubit>().state;
    final header = SectionHeader(
      title: 'Friends lately',
      actionLabel: state.items.isEmpty ? null : 'See all',
      onAction: () => context.push('/activity'),
    );
    final Widget body = switch (state.status) {
      LoadStatus.initial || LoadStatus.loading => const ListSkeleton(count: 2, leadingWidth: 36, leadingHeight: 36),
      LoadStatus.failure => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: context.read<FeedCubit>().refresh,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text("Couldn't load friends · Retry"),
        ),
      ),
      _ when state.items.isEmpty => Align(
        alignment: Alignment.centerLeft,
        child: TextButton(onPressed: onFindReaders, child: const Text('Follow readers to see what they’re reading')),
      ),
      _ => Column(
        children: [
          for (final (i, a) in state.items.take(4).indexed) ...[
            if (i > 0) const Divider(),
            ActivityCard(key: ValueKey(a.id), activity: a),
          ],
        ],
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (state.status == LoadStatus.loading || state.status == LoadStatus.initial)
          body
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: body,
          ),
      ],
    );
  }
}

class _ReaderResults extends StatefulWidget {
  const _ReaderResults({super.key, required this.query});

  final String query;

  @override
  State<_ReaderResults> createState() => _ReaderResultsState();
}

class _ReaderResultsState extends State<_ReaderResults> {
  Timer? _timer;
  Future<List<Profile>>? _future;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(_ReaderResults old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(SearchCubit.debounce, () {
      if (!mounted) return;
      setState(() {
        _future = sl<ProfileRepository>().searchProfiles(widget.query);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.trim().isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'Find readers',
        message: 'Search by username to follow friends.',
      );
    }
    return FutureBuilder<List<Profile>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SingleChildScrollView(child: ListSkeleton(count: 4, leadingWidth: 44, leadingHeight: 44));
        }
        if (snap.hasError) {
          return ErrorState(message: AppFailure.from(snap.error!).message, onRetry: _schedule);
        }
        final people = snap.data!;
        if (people.isEmpty) return const EmptyState(icon: Icons.person_search_outlined, title: 'No readers found');
        return ListView.builder(
          itemCount: people.length,
          itemBuilder: (_, i) => ListTile(
            key: ValueKey(people[i].id),
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            leading: AppAvatar(profile: people[i], size: 44),
            title: Text(people[i].name, style: context.text.titleSmall),
            subtitle: Text(people[i].handle, style: context.text.bodySmall),
            onTap: () => context.push(Routes.user(people[i].id)),
          ),
        );
      },
    );
  }
}
