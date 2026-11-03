import 'package:bookmarkd/app/di.dart';
import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/widgets/book_cover.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/library/domain/library_entry.dart';
import 'package:bookmarkd/features/library/domain/reading_status.dart';
import 'package:bookmarkd/features/library/presentation/library_cubit.dart';
import 'package:bookmarkd/features/reading/domain/progress_update.dart';
import 'package:bookmarkd/features/reading/domain/reading_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'finish_sheet.dart';

Future<void> showLogSheet(BuildContext context, LibraryEntry entry) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: context.colors.surface,
  barrierColor: const Color(0x731C1A17),
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg))),
  builder: (_) => BlocProvider.value(
    value: context.read<LibraryCubit>(),
    child: _LogSheet(entry: entry, parent: context),
  ),
);

class _LogSheet extends StatefulWidget {
  const _LogSheet({required this.entry, required this.parent});

  final LibraryEntry entry;
  final BuildContext parent;

  @override
  State<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<_LogSheet> {
  late final int? _pages = widget.entry.book.pageCount;

  bool get _byPage => _pages != null;

  int get _max => _pages ?? 100;
  late final int _last = _byPage ? widget.entry.currentPage ?? 0 : widget.entry.progressPercentDisplay;
  late int? _value = _last;
  late final _field = TextEditingController(text: '$_last');
  late final Future<ReadingSession?> _lastSession = sl<LibraryRepository>()
      .sessions(widget.entry.id)
      .then((s) => s.firstOrNull, onError: (_) => null);

  List<int> get _steps => _byPage ? const [10, 25, 50] : const [5, 10, 25];

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _set(int value) {
    HapticFeedback.selectionClick();
    final text = '$value';
    _field.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() => _value = value);
  }

  String? get _error {
    if (_byPage) return ProgressUpdate.validatePage(_value, pageCount: _pages!);
    if (_value == null) return 'Enter a percentage';
    if (_value! > 100) return 'Up to 100%';
    return null;
  }

  int get _percent => _value == null ? 0 : (_byPage ? (_value! * 100 / _pages!).round() : _value!).clamp(0, 100);

  Future<void> _save() async {
    final cubit = context.read<LibraryCubit>();
    final parent = widget.parent;
    final update = _byPage ? ProgressUpdate.page(_value!, pageCount: _pages!) : ProgressUpdate.percent(_value!);
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    try {
      final saved = await cubit.logProgress(widget.entry, update);
      if (update.isComplete && saved.status != ReadingStatus.finished && parent.mounted) {
        await showFinishSheet(parent, saved);
      }
    } catch (e) {
      if (parent.mounted) showMessage(parent, AppFailure.from(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.entry.book;
    final c = context.colors;
    final delta = (_value ?? _last) - _last;
    final error = _error;
    final amount = _byPage ? '$delta ${delta == 1 ? 'page' : 'pages'}' : '$delta%';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BookCover(book: book, width: 32),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyLarge?.prose.copyWith(fontSize: 18),
                      ),
                      Text(
                        book.authorLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: c.textSecondary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: Space.lg),
            Text('Where are you now?', style: context.text.headlineSmall?.prose.copyWith(fontSize: 26, height: 1.2)),
            const SizedBox(height: Space.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (_byPage) ...[
                  Text('Page', style: context.text.bodyMedium?.copyWith(fontSize: 15, color: c.textSecondary)),
                  const SizedBox(width: 10),
                ],
                SizedBox(
                  width: 128,
                  child: TextField(
                    controller: _field,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                    onChanged: (t) => setState(() => _value = int.tryParse(t)),
                    onSubmitted: (_) => error == null ? _save() : null,
                    style: TextStyle(
                      fontFamily: AppTheme.serif,
                      fontSize: 52,
                      height: 1,
                      color: c.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      contentPadding: const EdgeInsets.only(bottom: Space.xxs),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.textPrimary, width: 2)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.accent, width: 2)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _byPage ? 'of $_pages' : '%',
                  style: TextStyle(fontFamily: AppTheme.serif, fontSize: 24, color: c.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            FutureBuilder<ReadingSession?>(
              future: _lastSession,
              builder: (_, snap) {
                final since = snap.data == null ? 'last time' : _sinceLabel(snap.data!.readOn);
                return Text(
                  error ?? (delta > 0 ? '+$amount since $since · $_percent%' : '$_percent% of the book'),
                  style: context.text.bodySmall?.copyWith(
                    color: error != null ? c.danger : c.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                );
              },
            ),
            const SizedBox(height: Space.lg),
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                for (final step in _steps)
                  _Chip(
                    label: '+$step${_byPage ? '' : '%'}',
                    selected: _value == (_last + step).clamp(0, _max),
                    onTap: _last >= _max ? null : () => _set((_last + step).clamp(0, _max)),
                  ),
                _Chip(label: 'I finished it', selected: false, onTap: () => _set(_max)),
              ],
            ),
            const SizedBox(height: Space.lg),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: error == null ? _save : null,
              child: Text(delta > 0 ? 'Log $amount' : (_byPage ? 'Save page' : 'Save progress')),
            ),
            const SizedBox(height: 10),
            FutureBuilder<ReadingSession?>(
              future: _lastSession,
              builder: (_, snap) {
                final s = snap.data;
                final text = snap.connectionState != ConnectionState.done
                    ? ''
                    : s == null
                    ? 'First log for this book'
                    : 'Last logged ${s.toPage != null ? 'p. ${s.toPage}' : '${s.percent}%'} · ${_dayLabel(s.readOn)}';
                return Text(
                  text,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          backgroundColor: selected ? c.accentSoft : c.surface,
          foregroundColor: selected ? c.accent : c.textPrimary,
          side: BorderSide(color: selected ? c.accent : c.border),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}

int _daysAgo(DateTime day) => DateUtils.dateOnly(DateTime.now()).difference(DateUtils.dateOnly(day)).inDays;

String _dayLabel(DateTime day) => switch (_daysAgo(day)) {
  <= 0 => 'today',
  1 => 'yesterday',
  _ => DateFormat('d MMM').format(day),
};

String _sinceLabel(DateTime day) => switch (_daysAgo(day)) {
  <= 0 => 'earlier today',
  1 => 'yesterday',
  _ => DateFormat('d MMM').format(day),
};
