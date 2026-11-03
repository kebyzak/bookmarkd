import 'package:bookmarkd/app/di.dart';
import 'package:bookmarkd/app/router/app_router.dart';
import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:bookmarkd/features/search/presentation/search_cubit.dart';
import 'package:bookmarkd/features/search/presentation/search_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AuthorPage extends StatelessWidget {
  const AuthorPage({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => SearchCubit(sl(), author: name)..retry(),
    child: _AuthorView(name: name),
  );
}

class _AuthorView extends StatefulWidget {
  const _AuthorView({required this.name});

  final String name;

  @override
  State<_AuthorView> createState() => _AuthorViewState();
}

class _AuthorViewState extends State<_AuthorView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    context.read<SearchCubit>().queryChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SearchCubit>().state;
    final filtered = _controller.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AUTHOR',
                    style: context.text.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: Space.xxs),
                  Semantics(header: true, child: Text(widget.name, style: context.text.displaySmall)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _controller,
                    onChanged: (v) {
                      setState(() {});
                      context.read<SearchCubit>().queryChanged(v);
                    },
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => context.read<SearchCubit>().submitted(),
                    decoration: InputDecoration(
                      hintText: 'Search their books',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: filtered
                          ? IconButton(tooltip: 'Clear', icon: const Icon(Icons.close_rounded), onPressed: _clear)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BookResults(
                state: state,
                onOpen: (book) => context.push(Routes.book(book.key)),
                emptyMessage: filtered
                    ? 'No title by ${widget.name} matches that.'
                    : 'The catalog has no books listed under this name.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
