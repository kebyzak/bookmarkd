import 'package:bookmarkd/app/di.dart';
import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/widgets/book_cover.dart';
import 'package:bookmarkd/core/widgets/rating_stars.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/library/domain/library_entry.dart';
import 'package:bookmarkd/features/library/presentation/library_cubit.dart';
import 'package:bookmarkd/features/reviews/domain/review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WriteReviewPage extends StatefulWidget {
  const WriteReviewPage({super.key, required this.bookKey});

  final String bookKey;

  @override
  State<WriteReviewPage> createState() => _WriteReviewPageState();
}

class _WriteReviewPageState extends State<WriteReviewPage> {
  final _form = GlobalKey<FormState>();
  final _body = TextEditingController();
  bool _spoilers = false;
  bool _busy = false;
  Review? _existing;
  late final Future<void> _loading = _load();

  Future<void> _load() async {
    final review = await sl<ReviewRepository>().mine(widget.bookKey);
    if (!mounted || review == null) return;
    _existing = review;
    _body.text = review.body;
    setState(() => _spoilers = review.containsSpoilers);
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showMessage(context, done);
      context.pop();
    } catch (e) {
      if (mounted) showMessage(context, AppFailure.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    _run(
      () => sl<ReviewRepository>().upsert(bookId: widget.bookKey, body: _body.text, containsSpoilers: _spoilers),
      _existing == null ? 'Review posted' : 'Review updated',
    );
  }

  void _delete() => _run(() => sl<ReviewRepository>().delete(_existing!.id), 'Review deleted');

  bool get _dirty =>
      !_busy && (_body.text != (_existing?.body ?? '') || _spoilers != (_existing?.containsSpoilers ?? false));

  @override
  Widget build(BuildContext context) {
    final entry = context.select<LibraryCubit, LibraryEntry?>(
      (c) => c.state.byId.values.where((e) => e.book.id == widget.bookKey).firstOrNull,
    );
    return UnsavedChangesGuard(
      dirty: _dirty,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_existing == null ? 'Write a review' : 'Edit review'),
          actions: [
            if (_existing != null)
              IconButton(
                tooltip: 'Delete review',
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        body: FutureBuilder<void>(
          future: _loading,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (entry == null) {
              return const EmptyState(
                icon: Icons.rate_review_outlined,
                title: 'Add the book first',
                message: 'You can review books on your shelf.',
              );
            }
            return Form(
              key: _form,
              onChanged: () => setState(() {}),
              child: ListView(
                padding: const EdgeInsets.all(Space.gutter),
                children: [
                  Row(
                    children: [
                      BookCover(book: entry.book, width: 48),
                      const SizedBox(width: Space.md),
                      Expanded(child: Text(entry.book.title, style: context.text.titleMedium?.serif)),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  Text('Your rating', style: context.text.labelSmall),
                  const SizedBox(height: Space.xs),
                  RatingInput(
                    value: entry.rating,
                    onChanged: (r) => context.read<LibraryCubit>().rate(entry, r).catchError((Object e) {
                      if (context.mounted) showMessage(context, AppFailure.from(e).message);
                    }),
                  ),
                  const SizedBox(height: Space.lg),
                  TextFormField(
                    controller: _body,
                    validator: validateReviewBody,
                    minLines: 8,
                    maxLines: 20,
                    maxLength: 5000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'What did you think?', alignLabelWithHint: true),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _spoilers,
                    onChanged: (v) => setState(() => _spoilers = v),
                    title: const Text('Contains spoilers'),
                    subtitle: const Text('Readers will tap to reveal it'),
                    activeThumbColor: context.colors.accent,
                  ),
                  const SizedBox(height: Space.md),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onAccent),
                          )
                        : Text(_existing == null ? 'Post review' : 'Save changes'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
