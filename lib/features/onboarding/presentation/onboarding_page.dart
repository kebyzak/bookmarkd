import 'package:bookmarkd/app/di.dart';
import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/widgets/common.dart';
import 'package:bookmarkd/core/widgets/skeleton.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/auth/presentation/session_cubit.dart';
import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:bookmarkd/features/books/presentation/widgets/book_list_tile.dart';
import 'package:bookmarkd/features/library/domain/reading_status.dart';
import 'package:bookmarkd/features/library/presentation/library_cubit.dart';
import 'package:bookmarkd/features/profile/domain/profile.dart';
import 'package:bookmarkd/features/search/presentation/search_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pages = PageController();
  final _usernameForm = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _displayName = TextEditingController();
  int _step = 0;
  int? _goal = 12;
  bool _busy = false;
  late Profile _profile = context.read<SessionCubit>().profile!;

  static const _stepCount = 4;

  @override
  void dispose() {
    _pages.dispose();
    _username.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _guarded(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showMessage(context, AppFailure.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _advance() {
    FocusScope.of(context).unfocus();
    setState(() => _step++);
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(_step);
    } else {
      _pages.animateToPage(_step, duration: Motion.normal, curve: Motion.curve);
    }
  }

  Future<void> _saveUsername() async {
    if (!_usernameForm.currentState!.validate()) return;
    await _guarded(() async {
      final name = _username.text.trim();
      final repo = sl<ProfileRepository>();
      if (!await repo.isUsernameAvailable(name, exceptUserId: _profile.id)) {
        throw const AppFailure.conflict('That username is taken.');
      }
      final display = _displayName.text.trim();
      _profile = await repo.updateProfile(
        _profile.copyWith(username: name, displayName: () => display.isEmpty ? null : display),
      );
      _advance();
    });
  }

  Future<void> _pickAvatar() => _guarded(() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
    if (file == null) return;
    final ext = file.name.split('.').last.toLowerCase() == 'png' ? 'png' : 'jpeg';
    final repo = sl<ProfileRepository>();
    final url = await repo.uploadAvatar(_profile.id, await file.readAsBytes(), extension: ext);
    final updated = await repo.updateProfile(_profile.copyWith(avatarUrl: () => url));
    setState(() => _profile = updated);
  });

  Future<void> _saveGoal() => _guarded(() async {
    _profile = await sl<ProfileRepository>().updateProfile(_profile.copyWith(readingGoal: () => _goal));
    _advance();
  });

  Future<void> _finish() => _guarded(() async {
    final done = await sl<ProfileRepository>().updateProfile(_profile.copyWith(onboarded: true));
    if (mounted) context.read<SessionCubit>().profileUpdated(done);
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: _StepDots(step: _step, count: _stepCount),
      centerTitle: true,
      automaticallyImplyLeading: false,
    ),
    body: SafeArea(
      child: PageView(
        controller: _pages,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _StepLayout(
            title: 'Pick a username',
            subtitle: 'This is how other readers find you.',
            primaryLabel: 'Continue',
            busy: _busy,
            onPrimary: _saveUsername,
            child: Form(
              key: _usernameForm,
              child: Column(
                children: [
                  TextFormField(
                    controller: _username,
                    validator: validateUsername,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: 'username', prefixText: '@'),
                  ),
                  const SizedBox(height: Space.sm),
                  TextFormField(
                    controller: _displayName,
                    maxLength: 60,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'Display name (optional)', counterText: ''),
                  ),
                ],
              ),
            ),
          ),
          _StepLayout(
            title: 'Add a profile photo',
            subtitle: 'Optional. You can change it any time.',
            primaryLabel: 'Continue',
            busy: _busy,
            onPrimary: _advance,
            child: Center(
              child: Column(
                children: [
                  AppAvatar(profile: _profile, size: 112),
                  const SizedBox(height: Space.md),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickAvatar,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(_profile.avatarUrl == null ? 'Choose photo' : 'Change photo'),
                  ),
                ],
              ),
            ),
          ),
          _StepLayout(
            title: 'Set a reading goal',
            subtitle: 'How many books would you like to finish this year?',
            primaryLabel: 'Continue',
            secondaryLabel: 'Skip',
            busy: _busy,
            onPrimary: _saveGoal,
            onSecondary: () {
              _goal = null;
              _saveGoal();
            },
            child: _GoalPicker(value: _goal ?? 12, onChanged: (v) => setState(() => _goal = v)),
          ),
          _StepLayout(
            title: 'Add your first books',
            subtitle: 'Search for something you want to read or have read.',
            primaryLabel: 'Start reading',
            busy: _busy,
            onPrimary: _finish,
            expandChild: true,
            child: const _FirstBooks(),
          ),
        ],
      ),
    ),
  );
}

class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    required this.busy,
    this.secondaryLabel,
    this.onSecondary,
    this.expandChild = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool busy;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.headlineMedium),
          const SizedBox(height: Space.xs),
          Text(subtitle, style: context.text.bodyLarge?.copyWith(color: context.colors.textSecondary)),
        ],
      ),
    );
    final actions = Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onPrimary,
              child: busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onAccent),
                    )
                  : Text(primaryLabel),
            ),
          ),
          if (secondaryLabel != null) TextButton(onPressed: busy ? null : onSecondary, child: Text(secondaryLabel!)),
        ],
      ),
    );
    if (expandChild) {
      return Column(
        children: [
          header,
          Expanded(child: child),
          actions,
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              header,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                child: child,
              ),
            ],
          ),
        ),
        actions,
      ],
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Step ${step + 1} of $count',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: Motion.normal,
          curve: Motion.curve,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == step ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i <= step ? context.colors.accent : context.colors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    ),
  );
}

class _GoalPicker extends StatelessWidget {
  const _GoalPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.outlined(
            tooltip: 'Fewer books',
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 120,
            child: Text('$value', textAlign: TextAlign.center, style: context.text.displaySmall),
          ),
          IconButton.outlined(
            tooltip: 'More books',
            onPressed: value < 1000 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      Text(value == 1 ? 'book this year' : 'books this year', style: context.text.bodyMedium),
      const SizedBox(height: Space.lg),
      Wrap(
        spacing: Space.xs,
        children: [
          6,
          12,
          24,
          52,
        ].map((n) => ChoiceChip(label: Text('$n'), selected: value == n, onSelected: (_) => onChanged(n))).toList(),
      ),
    ],
  );
}

class _FirstBooks extends StatelessWidget {
  const _FirstBooks();

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => SearchCubit(sl()),
    child: Builder(
      builder: (context) {
        final search = context.watch<SearchCubit>().state;
        final added = context.select<LibraryCubit, int>((c) => c.state.byId.length);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: TextField(
                onChanged: context.read<SearchCubit>().queryChanged,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Title, author or ISBN',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            if (added > 0)
              Padding(
                padding: const EdgeInsets.only(top: Space.sm),
                child: Text(
                  '$added on your shelf',
                  style: context.text.labelMedium?.copyWith(color: context.colors.accent),
                ),
              ),
            Expanded(
              child: switch (search.status) {
                LoadStatus.initial => const SizedBox.shrink(),
                LoadStatus.loading => const SingleChildScrollView(child: ListSkeleton(count: 4)),
                LoadStatus.failure => ErrorState(
                  message: search.failure!.message,
                  onRetry: context.read<SearchCubit>().retry,
                ),
                LoadStatus.success when search.results.isEmpty => const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                ),
                LoadStatus.success => ListView.builder(
                  itemCount: search.results.length,
                  itemBuilder: (_, i) => _QuickAddTile(book: search.results[i]),
                ),
              },
            ),
          ],
        );
      },
    ),
  );
}

class _QuickAddTile extends StatelessWidget {
  const _QuickAddTile({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final onShelf = context.select<LibraryCubit, bool>((c) => c.state.entryFor(book) != null);
    Future<void> add() async {
      try {
        await context.read<LibraryCubit>().add(book, ReadingStatus.wantToRead);
      } catch (e) {
        if (context.mounted) showMessage(context, AppFailure.from(e).message);
      }
    }

    return BookListTile(
      key: ValueKey(book.key),
      book: book,
      onTap: onShelf ? () {} : add,
      trailing: IconButton(
        tooltip: onShelf ? 'On your shelf' : 'Add to Want to Read',
        onPressed: onShelf ? null : add,
        icon: Icon(
          onShelf ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
          color: context.colors.accent,
        ),
      ),
    );
  }
}
