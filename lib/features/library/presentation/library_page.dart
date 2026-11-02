import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/book_cover.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/rating_stars.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../domain/library_entry.dart';
import '../domain/library_query.dart';
import '../domain/reading_status.dart';
import 'library_cubit.dart';
import 'library_sheet.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  static const _gridPref = 'library_grid_view';
  LibraryQuery _query = const LibraryQuery();
  bool _grid = true;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    SharedPreferencesAsync()
        .getBool(_gridPref)
        .then((v) {
          if (v != null && mounted) setState(() => _grid = v);
        })
        .catchError((_) {});
  }

  void _toggleLayout() {
    setState(() => _grid = !_grid);
    SharedPreferencesAsync().setBool(_gridPref, _grid).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryCubit>().state;
    final counts = statusCounts(library.byId.values);
    final shown = _query.apply(library.byId.values);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: context.read<LibraryCubit>().reload,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header(context, library.byId.length)),
              SliverToBoxAdapter(child: _filters(counts, library.byId.length)),
              ..._body(context, library, shown),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, int total) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.xs, Space.xs),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Library', style: context.text.headlineMedium)),
            IconButton(
              tooltip: 'Search library',
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) _query = _query.copyWith(search: '');
              }),
              icon: Icon(_searching ? Icons.search_off_rounded : Icons.search_rounded),
            ),
            PopupMenuButton<LibrarySort>(
              tooltip: 'Sort',
              icon: const Icon(Icons.swap_vert_rounded),
              initialValue: _query.sort,
              onSelected: (s) => setState(() => _query = _query.copyWith(sort: s)),
              itemBuilder: (_) => LibrarySort.values.map((s) => PopupMenuItem(value: s, child: Text(s.label))).toList(),
            ),
            IconButton(
              tooltip: _grid ? 'Show as list' : 'Show as grid',
              onPressed: _toggleLayout,
              icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
            ),
          ],
        ),
        Text(
          '$total ${total == 1 ? 'book' : 'books'} · sorted by ${_query.sort.label.toLowerCase()}',
          style: context.text.bodySmall,
        ),
        AnimatedSize(
          duration: Motion.normal,
          child: _searching
              ? Padding(
                  padding: const EdgeInsets.only(top: Space.sm, right: Space.sm),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = _query.copyWith(search: v)),
                    decoration: const InputDecoration(
                      hintText: 'Filter by title or author',
                      prefixIcon: Icon(Icons.filter_list_rounded),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    ),
  );

  Widget _filters(Map<ReadingStatus, int> counts, int total) {
    Widget chip(String label, int count, ReadingStatus? status) => Padding(
      padding: const EdgeInsets.only(right: Space.xs),
      child: ChoiceChip(
        label: Text('$label  $count'),
        selected: _query.status == status,
        onSelected: (_) => setState(() => _query = _query.copyWith(status: () => status)),
      ),
    );
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.xxs),
        children: [
          chip('All', total, null),
          chip('Reading', counts[ReadingStatus.reading]!, ReadingStatus.reading),
          chip('Want to Read', counts[ReadingStatus.wantToRead]!, ReadingStatus.wantToRead),
          chip('Finished', counts[ReadingStatus.finished]!, ReadingStatus.finished),
          chip('DNF', counts[ReadingStatus.dnf]!, ReadingStatus.dnf),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, LibraryState library, List<LibraryEntry> shown) {
    if (library.status == LoadStatus.loading || library.status == LoadStatus.initial) {
      return [const SliverToBoxAdapter(child: ListSkeleton(count: 6))];
    }
    if (library.status == LoadStatus.failure) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(message: library.failure!.message, onRetry: context.read<LibraryCubit>().reload),
        ),
      ];
    }
    if (shown.isEmpty) {
      final empty = library.byId.isEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.auto_stories_outlined,
            title: empty ? 'Your shelf is empty' : 'Nothing here',
            message: empty ? 'Search for a book you love and add it to your library.' : 'No books match this filter.',
            action: empty
                ? FilledButton(onPressed: () => context.go('/search'), child: const Text('Find books'))
                : null,
          ),
        ),
      ];
    }
    void open(LibraryEntry e) => context.push(Routes.book(e.book.id!));

    if (_grid) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.crossAxisExtent / 120).floor().clamp(3, 6);
              final width = (constraints.crossAxisExtent - Space.md * (columns - 1)) / columns;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: Space.lg,
                  crossAxisSpacing: Space.md,
                  mainAxisExtent: width / coverAspectRatio + 26,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) =>
                      _GridItem(key: ValueKey(shown[i].id), entry: shown[i], width: width, onTap: () => open(shown[i])),
                  childCount: shown.length,
                ),
              );
            },
          ),
        ),
      ];
    }
    return [
      SliverList.builder(
        itemCount: shown.length,
        itemBuilder: (_, i) => _ListItem(key: ValueKey(shown[i].id), entry: shown[i], onTap: () => open(shown[i])),
      ),
    ];
  }
}

class _GridItem extends StatelessWidget {
  const _GridItem({super.key, required this.entry, required this.width, required this.onTap});
  final LibraryEntry entry;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPress: () => showLibrarySheet(context, entry.book),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            BookCover(book: entry.book, width: width, onTap: onTap),
            if (entry.status == ReadingStatus.reading)
              Positioned(left: 6, right: 6, bottom: 6, child: AppProgressBar(value: entry.progress, height: 4)),
            if (entry.isFavorite)
              const Positioned(top: 6, right: 6, child: Icon(Icons.favorite_rounded, size: 16, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 14,
          child: entry.rating != null
              ? RatingStars(stars: entry.rating!.stars, size: 12)
              : Text(entry.status.shortLabel, style: context.text.labelSmall?.copyWith(letterSpacing: 0)),
        ),
      ],
    ),
  );
}

class _ListItem extends StatelessWidget {
  const _ListItem({super.key, required this.entry, required this.onTap});
  final LibraryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    onLongPress: () => showLibrarySheet(context, entry.book),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.sm),
      child: Row(
        children: [
          BookCover(book: entry.book, width: 52),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                Text(entry.book.authorLine, maxLines: 1, style: context.text.bodySmall),
                const SizedBox(height: Space.xs),
                if (entry.status == ReadingStatus.reading)
                  Row(
                    children: [
                      Expanded(child: AppProgressBar(value: entry.progress, height: 4)),
                      const SizedBox(width: Space.xs),
                      Text('${entry.progressPercentDisplay}%', style: context.text.labelSmall),
                    ],
                  )
                else if (entry.rating != null)
                  RatingStars(stars: entry.rating!.stars)
                else
                  Text(entry.status.label, style: context.text.labelSmall?.copyWith(letterSpacing: 0)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Shelf actions',
            onPressed: () => showLibrarySheet(context, entry.book),
            icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}
