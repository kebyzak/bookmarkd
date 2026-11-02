import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/repositories.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../../books/domain/book.dart';
import '../../books/domain/catalog_query.dart';
import '../../books/presentation/widgets/book_list_tile.dart';
import '../../profile/domain/profile.dart';
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
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Search', style: context.text.headlineMedium),
                  const SizedBox(height: Space.md),
                  TextField(
                    controller: _controller,
                    onChanged: (v) {
                      setState(() {});
                      if (_scope == _Scope.books) context.read<SearchCubit>().queryChanged(v);
                    },
                    textInputAction: TextInputAction.search,
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
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ChoiceChip(
                          label: const Text('Readers'),
                          avatar: const Icon(Icons.people_outline_rounded, size: 16),
                          selected: _scope == _Scope.readers,
                          onSelected: (on) => setState(() => _scope = on ? _Scope.readers : _Scope.books),
                        ),
                        const SizedBox(width: Space.xs),
                        for (final mode in SearchMode.values) ...[
                          ChoiceChip(
                            label: Text(mode.label),
                            selected: _scope == _Scope.books && search.mode == mode,
                            onSelected: (_) {
                              setState(() => _scope = _Scope.books);
                              context.read<SearchCubit>()
                                ..queryChanged(_controller.text)
                                ..modeChanged(mode);
                            },
                          ),
                          const SizedBox(width: Space.xs),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.xs),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.normal,
                child: switch ((_scope, hasQuery)) {
                  (_Scope.readers, _) => _ReaderResults(key: const ValueKey('readers'), query: _controller.text),
                  (_Scope.books, false) => _Discover(key: const ValueKey('discover'), onOpen: _open),
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
    LoadStatus.loading => const SingleChildScrollView(child: ListSkeleton(count: 6)),
    LoadStatus.failure => ErrorState(message: state.failure!.message, onRetry: context.read<SearchCubit>().retry),
    LoadStatus.success when state.results.isEmpty => EmptyState(
      icon: Icons.search_off_rounded,
      title: 'No books found',
      message: state.mode == SearchMode.any
          ? 'Try a different spelling, or search by author or ISBN.'
          : 'Try searching across all fields.',
    ),
    LoadStatus.success => NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 400) context.read<SearchCubit>().loadMore();
        return false;
      },
      child: ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: state.results.length + (state.hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == state.results.length) {
            return const Padding(
              padding: EdgeInsets.all(Space.lg),
              child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          final book = state.results[i];
          return BookListTile(key: ValueKey(book.key), book: book, onTap: () => onOpen(book));
        },
      ),
    ),
  };
}

class _Discover extends StatelessWidget {
  const _Discover({super.key, required this.onOpen});
  final ValueChanged<Book> onOpen;

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
    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: Space.xl),
        children: [
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
            if (state.trending.isNotEmpty) ...[
              const SectionHeader(
                title: 'Trending this week',
                subtitle: 'Most activity from readers in the last 7 days',
              ),
              BookCarousel(books: state.trending, onTap: onOpen),
            ],
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
