import 'package:bookmarkd/app/router/app_router.dart';
import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/widgets/book_cover.dart';
import 'package:bookmarkd/core/widgets/rating_stars.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/library/domain/library_entry.dart';
import 'package:bookmarkd/features/library/domain/reading_status.dart';
import 'package:bookmarkd/features/reading/presentation/finish_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'library_cubit.dart';

const statusIcons = {
  ReadingStatus.wantToRead: Icons.bookmark_add_outlined,
  ReadingStatus.reading: Icons.menu_book_rounded,
  ReadingStatus.finished: Icons.check_circle_outline_rounded,
  ReadingStatus.dnf: Icons.do_not_disturb_on_outlined,
};

Future<void> showLibrarySheet(BuildContext context, Book book) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => BlocProvider.value(
    value: context.read<LibraryCubit>(),
    child: _LibrarySheet(book: book, parent: context),
  ),
);

class _LibrarySheet extends StatelessWidget {
  const _LibrarySheet({required this.book, required this.parent});

  final Book book;
  final BuildContext parent;

  Future<void> _run(BuildContext context, Future<void> Function() action, {bool close = false, String? done}) async {
    HapticFeedback.lightImpact();
    if (close) Navigator.of(context).pop();
    try {
      await action();
      if (done != null && parent.mounted) showMessage(parent, done);
    } catch (e) {
      if (parent.mounted) showMessage(parent, AppFailure.from(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cubit = context.read<LibraryCubit>();
    final entry = context.select<LibraryCubit, LibraryEntry?>((c) => c.state.entryFor(book));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BookCover(book: book, width: 44),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title, style: text.titleMedium?.serif, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(book.authorLine, style: text.bodySmall, maxLines: 1),
                  ],
                ),
              ),
              if (entry != null)
                IconButton(
                  tooltip: entry.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                  onPressed: () => _run(context, () => cubit.toggleFavorite(entry)),
                  icon: Icon(
                    entry.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: entry.isFavorite ? context.colors.danger : context.colors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          for (final status in ReadingStatus.values)
            _StatusOption(
              status: status,
              selected: entry?.status == status,
              onTap: () {
                if (entry != null && status == ReadingStatus.finished) {
                  Navigator.of(context).pop();
                  showFinishSheet(parent, entry);
                  return;
                }
                _run(
                  context,
                  () => entry == null ? cubit.add(book, status) : cubit.setStatus(entry, status),
                  close: entry == null,
                  done: entry == null ? 'Added to ${status.label}' : null,
                );
              },
            ),
          if (entry != null) ...[
            const SizedBox(height: Space.md),
            const Divider(),
            const SizedBox(height: Space.md),
            Text('Your rating', style: text.labelSmall),
            const SizedBox(height: Space.xs),
            Center(
              child: RatingInput(value: entry.rating, onChanged: (r) => _run(context, () => cubit.rate(entry, r))),
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      parent.push(Routes.progress(entry.book.id!));
                    },
                    icon: const Icon(Icons.trending_up_rounded, size: 18),
                    label: const Text('Progress'),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      parent.push(Routes.review(entry.book.id!));
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Review'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: context.colors.danger),
              onPressed: () => _confirmRemove(context, entry),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Remove from library'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, LibraryEntry entry) async {
    final cubit = context.read<LibraryCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Remove this book?'),
        content: const Text('Your status, progress and rating for it will be deleted. Reviews stay.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.colors.danger),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _run(context, () => cubit.remove(entry), close: true, done: 'Removed from library');
    }
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({required this.status, required this.selected, required this.onTap});

  final ReadingStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.xs),
    child: Material(
      color: selected ? context.colors.accentSoft : context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.card,
        side: BorderSide(color: selected ? context.colors.accent : context.colors.border),
      ),
      child: InkWell(
        borderRadius: Radii.card,
        onTap: selected ? null : onTap,
        child: Semantics(
          selected: selected,
          button: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 14),
            child: Row(
              children: [
                Icon(statusIcons[status], color: context.colors.accent, size: 22),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(status.label, style: Theme.of(context).textTheme.titleSmall)),
                AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: Motion.fast,
                  curve: Motion.curve,
                  child: Icon(Icons.check_rounded, color: context.colors.accent),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
