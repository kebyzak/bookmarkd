import 'package:bookmarkd/app/di.dart';
import 'package:bookmarkd/app/router/app_router.dart';
import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:bookmarkd/core/services/recent_searches_store.dart';
import 'package:bookmarkd/core/utils/formatters.dart';
import 'package:bookmarkd/core/widgets/book_cover.dart';
import 'package:bookmarkd/core/widgets/common.dart';
import 'package:bookmarkd/core/widgets/rating_stars.dart';
import 'package:bookmarkd/core/widgets/skeleton.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/books/domain/book_stats.dart';
import 'package:bookmarkd/features/library/domain/library_entry.dart';
import 'package:bookmarkd/features/library/domain/reading_status.dart';
import 'package:bookmarkd/features/library/presentation/library_cubit.dart';
import 'package:bookmarkd/features/library/presentation/library_sheet.dart';
import 'package:bookmarkd/features/reading/presentation/log_sheet.dart';
import 'package:bookmarkd/features/reviews/presentation/review_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'book_details_cubit.dart';

class BookDetailsPage extends StatelessWidget {
  const BookDetailsPage({super.key, required this.bookKey});

  final String bookKey;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => BookDetailsCubit(
      bookKey: bookKey,
      catalog: sl(),
      books: sl(),
      reviews: sl(),
      librarySynced: context.read<LibraryCubit>().synced,
    )..load(),
    child: const _BookDetailsView(),
  );
}

class _BookDetailsView extends StatelessWidget {
  const _BookDetailsView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BookDetailsCubit>().state;
    return MultiBlocListener(
      listeners: [
        BlocListener<LibraryCubit, LibraryState>(
          listenWhen: (a, b) {
            final book = state.book;
            return book != null && a.entryFor(book) == null && b.entryFor(book) != null;
          },
          listener: (context, library) {
            final book = state.book!;
            final cubit = context.read<BookDetailsCubit>();
            final entry = library.entryFor(book);
            if (book.id == null && entry != null) {
              cubit.bookStored(entry.book);
            } else {
              cubit.refreshCommunity();
            }
          },
        ),
        BlocListener<BookDetailsCubit, BookDetailsState>(
          listenWhen: (a, b) => a.book?.key != b.book?.key && b.book != null,
          listener: (_, s) => sl<RecentSearchesStore>().remember(s.book!),
        ),
      ],
      child: Scaffold(
        appBar: state.status == LoadStatus.success ? null : AppBar(),
        bottomNavigationBar: state.status == LoadStatus.success ? _ActionBar(book: state.book!) : null,
        body: switch (state.status) {
          LoadStatus.failure => SafeArea(
            child: ErrorState(message: state.failure!.message, onRetry: context.read<BookDetailsCubit>().load),
          ),
          LoadStatus.success => RefreshIndicator(
            onRefresh: context.read<BookDetailsCubit>().refreshCommunity,
            child: _Content(book: state.book!, stats: state.stats, state: state),
          ),
          _ => const _DetailsSkeleton(),
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.book, required this.stats, required this.state});

  final Book book;
  final BookStats stats;
  final BookDetailsState state;

  @override
  Widget build(BuildContext context) {
    final entry = context.select<LibraryCubit, LibraryEntry?>((c) => c.state.entryFor(book));
    final shown = entry?.book ?? book;

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xl),
      children: [
        _Header(book: shown, entry: entry),
        _NumbersRow(stats: stats, entry: entry),
        SectionHeader(
          title: 'From readers',
          actionLabel: entry != null ? 'Write a review' : null,
          onAction: entry == null ? null : () => context.push(Routes.review(entry.book.id!)),
        ),
        if (state.reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text(
              entry == null
                  ? 'No reviews yet. Add this book to your library to write the first one.'
                  : 'No reviews yet. Be the first.',
              style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
            ),
          )
        else
          for (final (i, r) in state.reviews.indexed) ...[
            if (i > 0) const Divider(indent: Space.gutter, endIndent: Space.gutter),
            ReviewTile(key: ValueKey(r.id), review: r),
          ],
        if (shown.description != null) ...[
          const SectionHeader(title: 'About'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: _ExpandableText(shown.description!),
          ),
        ],
        if (shown.categories.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: shown.categories.map((c) => Chip(label: Text(c))).toList(),
            ),
          ),
        ],
        const SectionHeader(title: 'Details'),
        _FactsTable(book: shown),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.book, required this.entry});

  final Book book;
  final LibraryEntry? entry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = coverTone(book.title);
    final facts = [
      if (book.publishedYear != null) '${book.publishedYear}',
      if (book.pageCount != null) '${book.pageCount} pages',
    ].join(' · ');

    return ColoredBox(
      color: Color.alphaBlend(tone.withValues(alpha: 0.16), c.background),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          MediaQuery.paddingOf(context).top + Space.xxs,
          Space.gutter,
          Space.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Transform.translate(
              offset: const Offset(-Space.sm, 0),
              child: Row(
                children: [
                  const BackButton(),
                  const Spacer(),
                  if (entry != null)
                    Transform.translate(
                      offset: const Offset(Space.sm * 2, 0),
                      child: IconButton(
                        tooltip: 'More options',
                        onPressed: () => showLibrarySheet(context, entry!.book),
                        icon: const Icon(Icons.more_horiz_rounded),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Space.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: Radii.cover,
                    boxShadow: [
                      BoxShadow(color: tone.withValues(alpha: 0.22), blurRadius: 20, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: BookCover(book: book, width: 112),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(book.title, style: context.text.displaySmall?.copyWith(fontSize: 32, height: 1.05)),
                      ),
                      if (book.subtitle != null) ...[
                        const SizedBox(height: Space.xxs),
                        Text(book.subtitle!, style: context.text.bodySmall?.copyWith(color: c.textSecondary)),
                      ],
                      const SizedBox(height: Space.xxs),
                      Text(book.authorLine, style: context.text.bodyLarge),
                      if (facts.isNotEmpty) ...[
                        const SizedBox(height: Space.xxs),
                        Text(
                          facts,
                          style: context.text.bodySmall?.copyWith(
                            color: c.textSecondary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumbersRow extends StatelessWidget {
  const _NumbersRow({required this.stats, required this.entry});

  final BookStats stats;
  final LibraryEntry? entry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final small = context.text.bodySmall?.copyWith(color: c.textSecondary, height: 1.4);
    final big = TextStyle(
      fontFamily: AppTheme.serif,
      fontSize: 30,
      height: 1,
      color: c.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final shelves = '${formatCount(stats.readerCount)} ${stats.readerCount == 1 ? 'shelf' : 'shelves'}';
    final ratings = '${formatCount(stats.ratingCount)} ${stats.ratingCount == 1 ? 'rating' : 'ratings'}';
    final mine = entry?.rating;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          if (stats.hasRatings) ...[
            Text(formatStars(stats.averageRating!), style: big),
            const SizedBox(width: 6),
            Icon(Icons.star_rounded, size: 18, color: c.star),
            const SizedBox(width: Space.md),
          ],
          Expanded(
            child: Text(
              stats.hasRatings
                  ? 'from $ratings\non $shelves'
                  : stats.readerCount > 0
                  ? 'No ratings yet\non $shelves'
                  : 'No ratings yet',
              style: small,
            ),
          ),
          if (mine != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('You', style: small),
                RatingStars(stars: mine.stars, size: 14),
              ],
            ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.book});

  final Book book;

  static const _shape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10)));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final entry = context.select<LibraryCubit, LibraryEntry?>((cubit) => cubit.state.entryFor(book));
    final adding = context.select<LibraryCubit, bool>((cubit) => cubit.state.adding.contains(book.key));

    final Widget content;
    if (entry == null) {
      content = FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: _shape),
        onPressed: adding ? null : () => showLibrarySheet(context, book),
        icon: adding
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add_rounded),
        label: Text(adding ? 'Adding…' : 'Add to library'),
      );
    } else {
      final pages = entry.book.pageCount;
      final detail = switch (entry.status) {
        ReadingStatus.reading =>
          pages != null && entry.currentPage != null
              ? 'p. ${entry.currentPage} · ${entry.progressPercentDisplay}%'
              : '${entry.progressPercentDisplay}%',
        ReadingStatus.finished => entry.finishedAt == null ? null : formatDate(entry.finishedAt!),
        _ => null,
      };
      content = Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: '${entry.status.label}${detail == null ? '' : ', $detail'}. Change status',
              excludeSemantics: true,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  backgroundColor: c.surface,
                  foregroundColor: c.textPrimary,
                  side: BorderSide(color: c.border),
                  shape: _shape,
                ),
                onPressed: () => showLibrarySheet(context, entry.book),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.status.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          if (detail != null)
                            Text(
                              detail,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: c.textSecondary,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
          if (entry.status == ReadingStatus.reading) ...[
            const SizedBox(width: 10),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(104, 52),
                shape: _shape,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: () => showLogSheet(context, entry),
              child: const Text('Log'),
            ),
          ],
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.sm),
          child: content,
        ),
      ),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText(this.text);

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AnimatedSize(
        duration: Motion.normal,
        curve: Motion.curve,
        alignment: Alignment.topCenter,
        child: Text(
          widget.text,
          maxLines: _open ? null : 6,
          overflow: _open ? null : TextOverflow.fade,
          style: context.text.bodyMedium?.copyWith(fontSize: 15, height: 1.55),
        ),
      ),
      if (widget.text.length > 320)
        TextButton(
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: () => setState(() => _open = !_open),
          child: Text(_open ? 'Show less' : 'Read more'),
        ),
    ],
  );
}

class _FactsTable extends StatelessWidget {
  const _FactsTable({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final facts = <(String, String)>[
      if (book.pageCount != null) ('Pages', '${book.pageCount}'),
      if (book.publisher != null) ('Publisher', book.publisher!),
      if (book.publishedDate != null) ('Published', book.publishedDate!),
      if (book.language != null) ('Language', book.language!.toUpperCase()),
      if (book.ids.isbn13 != null) ('ISBN-13', book.ids.isbn13!),
      if (book.ids.isbn10 != null) ('ISBN-10', book.ids.isbn10!),
    ];
    if (facts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        child: Text('No further details from the catalog.', style: context.text.bodySmall),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Column(
        children: [
          for (var i = 0; i < facts.length; i++) ...[
            if (i > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SizedBox(width: 96, child: Text(facts[i].$1, style: context.text.bodySmall)),
                  Expanded(child: SelectableText(facts[i].$2, style: context.text.bodyMedium)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(Space.gutter),
      child: Skeleton(
        child: const Column(
          children: [
            SkeletonBox(width: 180, height: 270),
            SizedBox(height: Space.lg),
            SkeletonBox(width: 220, height: 22),
            SizedBox(height: Space.xs),
            SkeletonBox(width: 140, height: 16),
            SizedBox(height: Space.lg),
            SkeletonBox(width: double.infinity, height: 52, radius: Radii.md),
          ],
        ),
      ),
    ),
  );
}
