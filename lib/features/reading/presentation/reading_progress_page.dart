import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/repositories.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/book_cover.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/states.dart';
import '../../library/domain/library_entry.dart';
import '../../library/domain/reading_status.dart';
import '../../library/presentation/library_cubit.dart';
import '../domain/progress_update.dart';
import '../domain/reading_session.dart';

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
  late final int? _pages = widget.entry.book.pageCount;
  late bool _byPage = _pages != null;
  late int _page = widget.entry.currentPage ?? 0;
  late int _percent = widget.entry.progressPercentDisplay;
  late final _pageField = TextEditingController(text: '$_page');
  late Future<List<ReadingSession>> _history = _loadHistory();
  bool _saving = false;

  Future<List<ReadingSession>> _loadHistory() => sl<LibraryRepository>().sessions(widget.entry.id);

  @override
  void dispose() {
    _pageField.dispose();
    super.dispose();
  }

  int get _shownPercent => _byPage ? (_page * 100 / _pages!).round() : _percent;

  void _setPage(int page) {
    final clamped = page.clamp(0, _pages!);
    if (clamped != _page) HapticFeedback.selectionClick();
    setState(() => _page = clamped);
    final text = '$clamped';
    if (_pageField.text != text) {
      _pageField.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  Future<void> _save() async {
    final cubit = context.read<LibraryCubit>();
    final update = _byPage ? ProgressUpdate.page(_page, pageCount: _pages!) : ProgressUpdate.percent(_percent);
    setState(() => _saving = true);
    final LibraryEntry saved;
    try {
      saved = await cubit.logProgress(widget.entry, update);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, AppFailure.from(e).message);
      }
      return;
    }
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    // The save is done: stop the spinner before asking anything else.
    setState(() {
      _saving = false;
      _history = _loadHistory();
    });
    if (update.isComplete && saved.status != ReadingStatus.finished) {
      await _offerFinish(saved);
    } else {
      showMessage(context, 'Progress saved · ${update.percent}%');
    }
  }

  /// Reaching 100% never changes status silently; the reader decides.
  Future<void> _offerFinish(LibraryEntry entry) async {
    final cubit = context.read<LibraryCubit>();
    final finish = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        icon: const Icon(Icons.celebration_outlined, color: AppColors.accent),
        title: const Text('You reached the end!'),
        content: Text('Mark ${entry.book.title} as finished?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Not yet')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Mark finished')),
        ],
      ),
    );
    if (finish != true) return;
    try {
      await cubit.setStatus(entry, ReadingStatus.finished);
      if (mounted) showMessage(context, 'Finished! Nice work.');
    } catch (e) {
      if (mounted) showMessage(context, AppFailure.from(e).message);
    }
  }

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
    return ListView(
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
                  Text(live.book.title, style: context.text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(live.book.authorLine, style: context.text.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: _shownPercent.toDouble()),
            duration: Motion.normal,
            builder: (_, v, _) => Text(
              '${v.round()}%',
              style: context.text.displaySmall?.copyWith(fontSize: 56, color: AppColors.accent),
            ),
          ),
        ),
        if (_byPage)
          Center(
            child: Text(
              'Page $_page of $_pages',
              style: context.text.titleMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        const SizedBox(height: Space.lg),
        if (_byPage) ..._pageControls() else _percentControls(),
        if (_pages != null)
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _byPage = !_byPage;
                if (!_byPage) _percent = _shownPercent;
              }),
              child: Text(_byPage ? 'Use percentage instead' : 'Use page numbers'),
            ),
          ),
        const SizedBox(height: Space.md),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save progress'),
        ),
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
                style: context.text.bodyMedium?.copyWith(color: AppColors.textSecondary),
              );
            }
            return Column(
              children: sessions
                  .map(
                    (s) => ListTile(
                      key: ValueKey(s.id),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.bookmark_outline_rounded, color: AppColors.accent),
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
    );
  }

  List<Widget> _pageControls() => [
    Slider(
      value: _page.toDouble(),
      max: _pages!.toDouble(),
      divisions: _pages,
      label: '$_page',
      onChanged: (v) => _setPage(v.round()),
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepButton(label: '−10', onTap: () => _setPage(_page - 10)),
        _StepButton(label: '−1', onTap: () => _setPage(_page - 1)),
        SizedBox(
          width: 88,
          child: TextField(
            controller: _pageField,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(vertical: 10)),
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null) setState(() => _page = n.clamp(0, _pages));
            },
          ),
        ),
        _StepButton(label: '+1', onTap: () => _setPage(_page + 1)),
        _StepButton(label: '+10', onTap: () => _setPage(_page + 10)),
      ],
    ),
  ];

  Widget _percentControls() => Column(
    children: [
      Slider(
        value: _percent.toDouble(),
        max: 100,
        divisions: 100,
        label: '$_percent%',
        onChanged: (v) {
          if (v.round() != _percent) HapticFeedback.selectionClick();
          setState(() => _percent = v.round());
        },
      ),
      if (_pages == null)
        Text(
          'This edition has no page count, so progress is a percentage.',
          style: context.text.bodySmall,
          textAlign: TextAlign.center,
        ),
    ],
  );
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed: onTap,
      child: Text(label),
    ),
  );
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
      style: context.text.bodyMedium?.copyWith(color: date == null ? AppColors.accent : AppColors.textPrimary),
    ),
  );
}
