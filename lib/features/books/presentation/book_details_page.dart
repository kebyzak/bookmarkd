import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/services/recent_searches_store.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/book_cover.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../../library/domain/library_entry.dart';
import '../../library/domain/reading_status.dart';
import '../../library/presentation/library_cubit.dart';
import '../../library/presentation/library_sheet.dart';
import '../../reviews/presentation/review_tile.dart';
import '../domain/book.dart';
import '../domain/book_stats.dart';
import 'book_details_cubit.dart';

class BookDetailsPage extends StatelessWidget {
  const BookDetailsPage({super.key, required this.bookKey});
  final String bookKey;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => BookDetailsCubit(bookKey: bookKey, catalog: sl(), books: sl(), reviews: sl())..load(),
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
        // Once the reader adds a catalog book, switch to its stored copy.
        BlocListener<LibraryCubit, LibraryState>(
          listener: (context, library) {
            final book = state.book;
            if (book == null || book.id != null) return;
            final entry = library.entryFor(book);
            if (entry != null) context.read<BookDetailsCubit>().bookStored(entry.book);
          },
        ),
        // Remember successfully opened books for "Recently searched".
        BlocListener<BookDetailsCubit, BookDetailsState>(
          listenWhen: (a, b) => a.book?.key != b.book?.key && b.book != null,
          listener: (_, s) => sl<RecentSearchesStore>().remember(s.book!),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent),
        extendBodyBehindAppBar: true,
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
    final width = MediaQuery.sizeOf(context).width;
    final coverWidth = (width * 0.46).clamp(140.0, 220.0);

    return ListView(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + kToolbarHeight, bottom: Space.xxl),
      children: [
        Center(
          child: BookCover(book: shown, width: coverWidth),
        ),
        const SizedBox(height: Space.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Column(
            children: [
              Text(shown.title, textAlign: TextAlign.center, style: context.text.headlineSmall),
              if (shown.subtitle != null) ...[
                const SizedBox(height: Space.xxs),
                Text(
                  shown.subtitle!,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: Space.xs),
              Text(
                shown.authorLine,
                textAlign: TextAlign.center,
                style: context.text.titleMedium?.copyWith(color: AppColors.accent),
              ),
              if (_publication(shown) case final pub?) ...[
                const SizedBox(height: Space.xxs),
                Text(pub, textAlign: TextAlign.center, style: context.text.bodySmall),
              ],
              const SizedBox(height: Space.md),
              _RatingsRow(stats: stats, entry: entry),
              const SizedBox(height: Space.lg),
              _PrimaryAction(book: shown, entry: entry),
            ],
          ),
        ),
        if (entry != null && entry.status == ReadingStatus.reading)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
            child: _ProgressCard(entry: entry),
          ),
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
        SectionHeader(
          title: 'Reviews',
          subtitle: state.reviews.isEmpty ? null : '${state.reviews.length} from readers',
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
              style: context.text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          )
        else
          ...state.reviews.map((r) => ReviewTile(key: ValueKey(r.id), review: r)),
      ],
    );
  }

  static String? _publication(Book b) {
    final parts = [if (b.publisher != null) b.publisher!, if (b.publishedYear != null) '${b.publishedYear}'];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _RatingsRow extends StatelessWidget {
  const _RatingsRow({required this.stats, required this.entry});
  final BookStats stats;
  final LibraryEntry? entry;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      if (stats.hasRatings)
        _RatingCell(
          label: 'Community · ${formatCount(stats.ratingCount)}',
          value: formatStars(stats.averageRating!),
          stars: stats.averageRating!,
        ),
      if (entry?.rating != null)
        _RatingCell(label: 'You', value: formatStars(entry!.rating!.stars), stars: entry!.rating!.stars),
      if (stats.readerCount > 0) _RatingCell(label: 'On shelves', value: formatCount(stats.readerCount)),
    ];
    if (cells.isEmpty) {
      return Text('No community ratings yet', style: context.text.bodySmall);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 32,
              color: AppColors.border,
              margin: const EdgeInsets.symmetric(horizontal: Space.md),
            ),
          cells[i],
        ],
      ],
    );
  }
}

class _RatingCell extends StatelessWidget {
  const _RatingCell({required this.label, required this.value, this.stars});
  final String label;
  final String value;
  final double? stars;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: context.text.titleMedium),
          if (stars != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.star_rounded, size: 16, color: AppColors.star),
          ],
        ],
      ),
      Text(label, style: context.text.bodySmall),
    ],
  );
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.book, required this.entry});
  final Book book;
  final LibraryEntry? entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    if (e == null) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => showLibrarySheet(context, book),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add to Library'),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.accentSoft,
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accentSoft),
        ),
        onPressed: () => showLibrarySheet(context, e.book),
        icon: Icon(statusIcons[e.status]),
        label: Text('${e.status.label}  ·  Edit'),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.entry});
  final LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final pages = entry.book.pageCount;
    final detail = pages != null && entry.currentPage != null
        ? 'Page ${entry.currentPage} of $pages'
        : '${entry.progressPercentDisplay}% read';
    return SurfaceCard(
      onTap: () => context.push(Routes.progress(entry.book.id!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(detail, style: context.text.titleSmall)),
              Text(
                '${entry.progressPercentDisplay}%',
                style: context.text.titleSmall?.copyWith(color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          AppProgressBar(value: entry.progress),
          const SizedBox(height: Space.xs),
          Text('Tap to update progress', style: context.text.bodySmall),
        ],
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
        alignment: Alignment.topCenter,
        child: Text(
          widget.text,
          maxLines: _open ? null : 6,
          overflow: _open ? null : TextOverflow.fade,
          style: context.text.bodyMedium,
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
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
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
      child: Column(
        children: [
          const SizedBox(height: kToolbarHeight),
          const SkeletonBox(width: 180, height: 270),
          const SizedBox(height: Space.lg),
          const SkeletonBox(width: 220, height: 22),
          const SizedBox(height: Space.xs),
          const SkeletonBox(width: 140, height: 16),
          const SizedBox(height: Space.lg),
          SkeletonBox(width: double.infinity, height: 52, radius: Radii.md),
        ],
      ),
    ),
  );
}
