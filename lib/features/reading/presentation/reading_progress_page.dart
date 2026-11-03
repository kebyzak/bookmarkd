import 'package:bookmarkd/app/di.dart';
import 'package:bookmarkd/app/router/app_router.dart';
import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/utils/formatters.dart';
import 'package:bookmarkd/core/widgets/book_cover.dart';
import 'package:bookmarkd/core/widgets/common.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/library/domain/library_entry.dart';
import 'package:bookmarkd/features/library/domain/reading_status.dart';
import 'package:bookmarkd/features/library/presentation/library_cubit.dart';
import 'package:bookmarkd/features/reading/domain/reading_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'log_sheet.dart';

class ReadingProgressPage extends StatelessWidget {
  const ReadingProgressPage({super.key, required this.bookKey});

  final String bookKey;

  @override
  Widget build(BuildContext context) {
    final entry = context.select<LibraryCubit, LibraryEntry?>(
      (c) => c.state.byId.values.where((e) => e.book.id == bookKey).firstOrNull,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Reading progress')),
      body: entry == null
          ? EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Not on your shelf',
              message: 'Add this book to your library to track progress.',
              action: FilledButton(
                onPressed: () => context.pushReplacement(Routes.book(bookKey)),
                child: const Text('View book'),
              ),
            )
          : _ProgressEditor(key: ValueKey(entry.id), entry: entry),
    );
  }
}

class _ProgressEditor extends StatefulWidget {
  const _ProgressEditor({super.key, required this.entry});

  final LibraryEntry entry;

  @override
  State<_ProgressEditor> createState() => _ProgressEditorState();
}

class _ProgressEditorState extends State<_ProgressEditor> {
  late Future<List<ReadingSession>> _history = _loadHistory();

  Future<List<ReadingSession>> _loadHistory() => sl<LibraryRepository>().sessions(widget.entry.id);

  Future<void> _pickDate({required bool start}) async {
    final e = context.read<LibraryCubit>().state.byId[widget.entry.id] ?? widget.entry;
    final now = DateTime.now();
    final initial = (start ? e.startedAt : e.finishedAt) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: start ? DateTime(1900) : (e.startedAt ?? DateTime(1900)),
      lastDate: start ? (e.finishedAt ?? now) : now,
    );
    if (picked == null || !mounted) return;
    try {
      await context.read<LibraryCubit>().setDates(
        e,
        startedAt: start ? picked : e.startedAt,
        finishedAt: start ? e.finishedAt : picked,
      );
    } catch (err) {
      if (mounted) showMessage(context, AppFailure.from(err).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = context.select<LibraryCubit, LibraryEntry>((c) => c.state.byId[widget.entry.id] ?? widget.entry);
    return BlocListener<LibraryCubit, LibraryState>(
      listenWhen: (a, b) {
        final before = a.byId[widget.entry.id];
        final after = b.byId[widget.entry.id];
        return before?.currentPage != after?.currentPage || before?.progressPercent != after?.progressPercent;
      },
      listener: (_, _) => setState(() => _history = _loadHistory()),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.xxl),
        children: [
          Row(
            children: [
              BookCover(book: live.book, width: 56),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      live.book.title,
                      style: context.text.titleMedium?.serif,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(live.book.authorLine, style: context.text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  live.book.pageCount != null && live.currentPage != null
                      ? 'p. ${live.currentPage} of ${live.book.pageCount}'
                      : 'Progress',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Text('${live.progressPercentDisplay}%', style: context.text.displaySmall),
            ],
          ),
          const SizedBox(height: Space.xs),
          AppProgressBar(value: live.progress, height: 3),
          if (live.status != ReadingStatus.finished) ...[
            const SizedBox(height: Space.lg),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
              ),
              onPressed: () => showLogSheet(context, live),
              child: const Text('Log progress'),
            ),
          ],
          const SizedBox(height: Space.lg),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _DateRow(label: 'Started', date: live.startedAt, onTap: () => _pickDate(start: true)),
                const Divider(),
                _DateRow(
                  label: 'Finished',
                  date: live.finishedAt,
                  onTap: live.status == ReadingStatus.finished ? () => _pickDate(start: false) : null,
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'History'),
          FutureBuilder<List<ReadingSession>>(
            future: _history,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: Padding(padding: EdgeInsets.all(Space.md), child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              if (snap.hasError) {
                return ErrorState(
                  message: AppFailure.from(snap.error!).message,
                  onRetry: () => setState(() {
                    _history = _loadHistory();
                  }),
                );
              }
              final sessions = snap.data!;
              if (sessions.isEmpty) {
                return Text(
                  'Your progress updates will appear here.',
                  style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
                );
              }
              return Column(
                children: sessions
                    .map(
                      (s) => ListTile(
                        key: ValueKey(s.id),
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.bookmark_outline_rounded, color: context.colors.accent),
                        title: Text(s.toPage != null ? 'Reached page ${s.toPage}' : 'Reached ${s.percent}%'),
                        subtitle: Text(
                          [formatDate(s.readOn), if (s.pagesRead != null) '+${s.pagesRead} pages'].join(' · '),
                        ),
                        trailing: Text('${s.percent}%', style: context.text.labelMedium),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, required this.date, required this.onTap});

  final String label;
  final DateTime? date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    enabled: onTap != null,
    title: Text(label, style: context.text.titleSmall),
    trailing: Text(
      date == null ? (onTap == null ? '—' : 'Set date') : formatDate(date!),
      style: context.text.bodyMedium?.copyWith(
        color: date == null ? context.colors.accent : context.colors.textPrimary,
      ),
    ),
  );
}
