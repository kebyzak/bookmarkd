import 'package:bookmarkd/app/di.dart';
import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/widgets/book_cover.dart';
import 'package:bookmarkd/core/widgets/rating_stars.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/auth/presentation/session_cubit.dart';
import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/library/domain/library_entry.dart';
import 'package:bookmarkd/features/library/domain/rating.dart';
import 'package:bookmarkd/features/library/domain/reading_status.dart';
import 'package:bookmarkd/features/library/domain/status_transition.dart';
import 'package:bookmarkd/features/library/presentation/library_cubit.dart';
import 'package:bookmarkd/features/reviews/domain/review.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

Future<void> showFinishSheet(BuildContext context, Book book) {
  HapticFeedback.heavyImpact();
  final cubit = context.read<LibraryCubit>();
  final goal = context.read<SessionCubit>().profile?.readingGoal;
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _FinishPage(book: book, goal: goal, parent: context),
      ),
    ),
  );
}

Future<DateTime?> pickFinishDate(BuildContext context, DateTime initial) {
  final today = DateUtils.dateOnly(DateTime.now());
  return showDatePicker(
    context: context,
    initialDate: initial.isAfter(today) ? today : initial,
    firstDate: DateTime(1900),
    lastDate: today,
    helpText: 'Finished on',
  );
}

const _ratingWords = ['Not for me', 'It was fine', 'Good', 'Really good', 'A favourite'];

class _FinishPage extends StatefulWidget {
  const _FinishPage({required this.book, required this.goal, required this.parent});

  final Book book;
  final int? goal;
  final BuildContext parent;

  @override
  State<_FinishPage> createState() => _FinishPageState();
}

class _FinishPageState extends State<_FinishPage> {
  late final DateTime _today = DateUtils.dateOnly(DateTime.now());
  late final LibraryEntry? _entry = context.read<LibraryCubit>().state.entryFor(widget.book);
  late DateTime _day = _today;
  late bool? _counted = _entry?.status == ReadingStatus.reading ? true : null;
  late Rating? _rating = _entry?.rating;
  final _note = TextEditingController();
  late final Future<Review?> _existingReview = widget.book.id == null
      ? Future.value()
      : sl<ReviewRepository>().mine(widget.book.id!).then((r) => r, onError: (_) => null);

  List<LibraryEntry> _earlierIn(int year) =>
      context
          .read<LibraryCubit>()
          .state
          .entries
          .where((e) => e.id != _entry?.id && e.status == ReadingStatus.finished && e.finishedAt?.year == year)
          .toList()
        ..sort((a, b) => a.finishedAt!.compareTo(b.finishedAt!));

  Future<void> _changeDate() async {
    final picked = await pickFinishDate(context, _day);
    if (picked != null && mounted) setState(() => _day = picked);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save({required bool withRating}) async {
    final cubit = context.read<LibraryCubit>();
    final parent = widget.parent;
    final when = _counted! ? ReadOn(_day) : const ReadSometimeAgo();
    final added = _entry == null;
    final rating = _rating;
    final note = _note.text.trim();
    Navigator.of(context).pop();
    try {
      final saved = await cubit.finish(widget.book, when);
      if (added && parent.mounted) showMessage(parent, 'Added to ${ReadingStatus.finished.label}');
      if (!withRating) return;
      if (rating != saved.rating) await cubit.rate(cubit.state.byId[saved.id] ?? saved, rating);
      if (note.isNotEmpty) {
        await sl<ReviewRepository>().upsert(bookId: saved.book.id!, body: note, containsSpoilers: false);
      }
    } catch (e) {
      if (parent.mounted) showMessage(parent, AppFailure.from(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final book = widget.book;
    final counted = _counted == true;
    final year = _day.year;
    final earlier = counted ? _earlierIn(year) : const <LibraryEntry>[];
    final number = earlier.length + 1;
    final goal = counted && year == _today.year ? widget.goal : null;
    final started = _entry?.startedAt;
    final days = !counted || started == null || started.isAfter(_day)
        ? null
        : _day.difference(DateUtils.dateOnly(started)).inDays + 1;
    final pages = book.pageCount;
    final span = [
      if (pages != null) '$pages pages',
      if (days != null) 'over $days ${days == 1 ? 'day' : 'days'}',
    ].join(' ');
    final left = goal == null ? null : goal - number;
    final dateLabel = DateFormat(year == _today.year ? 'd MMMM' : 'd MMMM y').format(_day);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xs, Space.xs, Space.xs, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: c.textSecondary, size: 20),
                  ),
                  Expanded(
                    child: Text(
                      (counted ? 'Finished · $dateLabel' : 'Finished').toUpperCase(),
                      textAlign: TextAlign.center,
                      style: context.text.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: Space.sm),
                    Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Motion.normal,
                        curve: Motion.curve,
                        builder: (_, t, child) => Opacity(
                          opacity: t,
                          child: Transform.scale(scale: reduceMotion ? 1 : 0.94 + 0.06 * t, child: child),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: Radii.cover,
                            boxShadow: [
                              BoxShadow(
                                color: coverTone(book.title).withValues(alpha: 0.25),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: BookCover(book: book, width: 116),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Semantics(
                      header: true,
                      child: AnimatedSwitcher(
                        duration: Motion.fast,
                        child: Text(
                          switch (_counted) {
                            true => 'Book $number of $year',
                            false => 'Read some time ago',
                            null => 'Finished',
                          },
                          key: ValueKey('$_counted|$year|$number'),
                          textAlign: TextAlign.center,
                          style: context.text.displaySmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      [
                        span.isEmpty ? book.title : '${book.title}, $span.',
                        if (left != null) left > 0 ? '$left to go for your goal.' : 'You reached your goal of $goal.',
                        if (_counted == false) "On your shelf, outside any year's goal.",
                      ].join('\n'),
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(color: c.textSecondary, height: 1.45),
                    ),
                    if (counted) ...[
                      const SizedBox(height: Space.lg),
                      _MiniShelf(earlier: earlier, current: book, year: year),
                    ],
                    const SizedBox(height: Space.lg),
                    _Choice(
                      icon: Icons.event_available_outlined,
                      title: year == _today.year && widget.goal != null
                          ? 'Count toward my $year goal'
                          : 'Count in my $year reading',
                      subtitle: counted ? 'Finished $dateLabel · Change date' : 'Finished today, or pick the day',
                      selected: counted,
                      onTap: counted ? _changeDate : () => setState(() => _counted = true),
                    ),
                    _Choice(
                      icon: Icons.history_rounded,
                      title: 'Read some time ago',
                      subtitle: 'No date needed. Not counted in any year.',
                      selected: _counted == false,
                      onTap: () => setState(() => _counted = false),
                    ),
                    const SizedBox(height: Space.lg),
                    Semantics(
                      header: true,
                      child: Text('How was it?', textAlign: TextAlign.center, style: context.text.titleLarge),
                    ),
                    const SizedBox(height: Space.xs),
                    Center(
                      child: RatingInput(value: _rating, onChanged: (r) => setState(() => _rating = r), size: 48),
                    ),
                    const SizedBox(height: Space.xxs),
                    SizedBox(
                      height: 18,
                      child: Text(
                        _rating == null ? '' : _ratingWords[_rating!.stars.ceil() - 1],
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                      ),
                    ),
                    FutureBuilder<Review?>(
                      future: _existingReview,
                      builder: (_, snap) {
                        if (snap.connectionState != ConnectionState.done || snap.data != null) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: Space.md),
                          child: TextField(
                            controller: _note,
                            minLines: 2,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            style: context.text.bodyLarge?.prose.copyWith(fontSize: 17, height: 1.4),
                            decoration: const InputDecoration(
                              labelText: 'A line about it (optional)',
                              hintText: 'What stayed with you?',
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: Space.lg),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    onPressed: _counted == null ? null : () => _save(withRating: true),
                    child: Text(switch (_counted) {
                      true => 'Save to my $year',
                      false => 'Save to Finished',
                      null => 'Choose how to save it',
                    }),
                  ),
                  const SizedBox(height: Space.xxs),
                  TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: _counted == null ? null : () => _save(withRating: false),
                    child: const Text('Rate it later'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Material(
        color: selected ? c.accentSoft : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.card,
          side: BorderSide(color: selected ? c.accent : c.border),
        ),
        child: InkWell(
          borderRadius: Radii.card,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Semantics(
            selected: selected,
            button: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: c.accent, size: 22),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.text.titleSmall),
                        const SizedBox(height: 2),
                        Text(subtitle, style: context.text.bodySmall?.copyWith(color: c.textSecondary)),
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: Motion.fast,
                    curve: Motion.curve,
                    child: Icon(Icons.check_rounded, color: c.accent),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniShelf extends StatelessWidget {
  const _MiniShelf({required this.earlier, required this.current, required this.year});

  final List<LibraryEntry> earlier;
  final Book current;
  final int year;
  static const _max = 14;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = earlier.length > _max - 1 ? earlier.sublist(earlier.length - (_max - 1)) : earlier;

    Widget spine(Book b, {bool isNew = false}) {
      final width = ((b.pageCount ?? 300) / 60).clamp(10.0, 19.0);
      final height = 48.0 + b.title.length * 7 % 14;
      final box = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: coverTone(b.title),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),
      );
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: isNew ? 4 : 1.5),
        child: isNew
            ? DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(border: Border.all(color: c.star, width: 2)),
                child: Padding(padding: const EdgeInsets.all(2), child: box),
              )
            : box,
      );
    }

    return Semantics(
      label: 'Your $year shelf, now ${earlier.length + 1} books',
      child: ExcludeSemantics(
        child: Container(
          height: 72,
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.textPrimary, width: 2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [for (final e in shown) spine(e.book), spine(current, isNew: true)],
          ),
        ),
      ),
    );
  }
}
