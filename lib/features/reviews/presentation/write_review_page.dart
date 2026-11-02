import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/repositories.dart';
import '../../../core/widgets/book_cover.dart';
import '../../../core/widgets/rating_stars.dart';
import '../../../core/widgets/states.dart';
import '../../library/domain/library_entry.dart';
import '../../library/presentation/library_cubit.dart';
import '../domain/review.dart';

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

  @override
  Widget build(BuildContext context) {
    final entry = context.select<LibraryCubit, LibraryEntry?>(
      (c) => c.state.byId.values.where((e) => e.book.id == widget.bookKey).firstOrNull,
    );
    return Scaffold(
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
            child: ListView(
              padding: const EdgeInsets.all(Space.gutter),
              children: [
                Row(
                  children: [
                    BookCover(book: entry.book, width: 48),
                    const SizedBox(width: Space.md),
                    Expanded(child: Text(entry.book.title, style: context.text.titleMedium)),
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
                  activeThumbColor: AppColors.accent,
                ),
                const SizedBox(height: Space.md),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_existing == null ? 'Post review' : 'Save changes'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
