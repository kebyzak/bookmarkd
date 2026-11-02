import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/book_cover.dart';
import '../../../library/presentation/library_cubit.dart';
import '../../domain/book.dart';

/// A book row: cover, title, author, year, and the reader's shelf status.
class BookListTile extends StatelessWidget {
  const BookListTile({super.key, required this.book, required this.onTap, this.trailing});

  final Book book;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final entry = context.select<LibraryCubit, String?>((c) => c.state.entryFor(book)?.status.shortLabel);
    final meta = [
      if (book.publishedYear != null) '${book.publishedYear}',
      if (book.pageCount != null) '${book.pageCount} pages',
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.sm),
        child: Row(
          children: [
            BookCover(book: book, width: 52),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    book.authorLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                  if (meta.isNotEmpty) ...[const SizedBox(height: 2), Text(meta, style: text.bodySmall)],
                  if (entry != null) ...[const SizedBox(height: Space.xs), StatusPill(label: entry)],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(20)),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.accent, letterSpacing: 0),
    ),
  );
}
