import 'package:bookmarkd/app/di.dart';
import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/widgets/book_cover.dart';
import 'package:bookmarkd/core/widgets/rating_stars.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/auth/presentation/session_cubit.dart';
import 'package:bookmarkd/features/library/domain/library_entry.dart';
import 'package:bookmarkd/features/library/domain/rating.dart';
import 'package:bookmarkd/features/library/domain/reading_status.dart';
import 'package:bookmarkd/features/library/presentation/library_cubit.dart';
import 'package:bookmarkd/features/reviews/domain/review.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

Future<void> showFinishSheet(BuildContext context, LibraryEntry entry) {
  HapticFeedback.heavyImpact();
  final cubit = context.read<LibraryCubit>();
  final goal = context.read<SessionCubit>().profile?.readingGoal;
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _FinishPage(entry: entry, goal: goal, parent: context),
      ),
    ),
  );
}

const _ratingWords = ['Not for me', 'It was fine', 'Good', 'Really good', 'A favourite'];

class _FinishPage extends StatefulWidget {
  const _FinishPage({required this.entry, required this.goal, required this.parent});

  final LibraryEntry entry;
  final int? goal;
  final BuildContext parent;

  @override
  State<_FinishPage> createState() => _FinishPageState();
}

class _FinishPageState extends State<_FinishPage> {
  late final DateTime _today = DateUtils.dateOnly(DateTime.now());
  late Rating? _rating = widget.entry.rating;
  final _note = TextEditingController();

  late final Future<Review?> _existingReview = sl<ReviewRepository>()
      .mine(widget.entry.book.id!)
      .then((r) => r, onError: (_) => null);

  late final List<LibraryEntry> _earlier =
      context
          .read<LibraryCubit>()
          .state
          .entries
          .where(
            (e) => e.id != widget.entry.id && e.status == ReadingStatus.finished && e.finishedAt?.year == _today.year,
          )
          .toList()
        ..sort((a, b) => a.finishedAt!.compareTo(b.finishedAt!));

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save({required bool withRating}) async {
    final cubit = context.read<LibraryCubit>();
    final parent = widget.parent;
    final id = widget.entry.id;
    final rating = _rating;
    final note = _note.text.trim();
    Navigator.of(context).pop();
    try {
      await cubit.setStatus(cubit.state.byId[id] ?? widget.entry, ReadingStatus.finished);
      if (!withRating) return;
      if (rating != widget.entry.rating) await cubit.rate(cubit.state.byId[id]!, rating);
      if (note.isNotEmpty) {
        await sl<ReviewRepository>().upsert(bookId: widget.entry.book.id!, body: note, containsSpoilers: false);
      }
    } catch (e) {
      if (parent.mounted) showMessage(parent, AppFailure.from(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final book = widget.entry.book;
    final number = _earlier.length + 1;
    final goal = widget.goal;
    final started = widget.entry.startedAt;
    final days = started == null ? null : _today.difference(DateUtils.dateOnly(started)).inDays + 1;
    final pages = book.pageCount;
    final span = [
      if (pages != null) '$pages pages',
      if (days != null) 'over $days ${days == 1 ? 'day' : 'days'}',
    ].join(' ');
    final left = goal == null ? null : goal - number;
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
                      'Finished · ${DateFormat('d MMMM').format(_today)}'.toUpperCase(),
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
                      child: Text(
                        'Book $number of ${_today.year}',
                        textAlign: TextAlign.center,
                        style: context.text.displaySmall,
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      [
                        span.isEmpty ? book.title : '${book.title}, $span.',
                        if (left != null) left > 0 ? '$left to go for your goal.' : 'You reached your goal of $goal.',
                      ].join('\n'),
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(color: c.textSecondary, height: 1.45),
                    ),
                    const SizedBox(height: Space.lg),
                    _MiniShelf(earlier: _earlier, current: widget.entry, year: _today.year),
                    const SizedBox(height: 26),
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
                    onPressed: () => _save(withRating: true),
                    child: Text('Save to my ${_today.year}'),
                  ),
                  const SizedBox(height: Space.xxs),
                  TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: () => _save(withRating: false),
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

class _MiniShelf extends StatelessWidget {
  const _MiniShelf({required this.earlier, required this.current, required this.year});

  final List<LibraryEntry> earlier;
  final LibraryEntry current;
  final int year;
  static const _max = 14;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = earlier.length > _max - 1 ? earlier.sublist(earlier.length - (_max - 1)) : earlier;

    Widget spine(LibraryEntry e, {bool isNew = false}) {
      final width = ((e.book.pageCount ?? 300) / 60).clamp(10.0, 19.0);
      final height = 48.0 + e.book.title.length * 7 % 14;
      final box = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: coverTone(e.book.title),
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
            children: [for (final e in shown) spine(e), spine(current, isNew: true)],
          ),
        ),
      ),
    );
  }
}
