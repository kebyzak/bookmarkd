import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/services/recent_searches_store.dart';
import '../features/auth/presentation/session_cubit.dart';
import '../features/library/presentation/library_cubit.dart';
import 'di.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class BookmarkdApp extends StatefulWidget {
  const BookmarkdApp({super.key, this.fontFamily});
  final String? fontFamily;

  @override
  State<BookmarkdApp> createState() => _BookmarkdAppState();
}

class _BookmarkdAppState extends State<BookmarkdApp> {
  late final SessionCubit _session = SessionCubit(sl(), sl());
  late final LibraryCubit _library = LibraryCubit(sl(), sl());
  late final GoRouter _router = createRouter(_session);

  @override
  void dispose() {
    _router.dispose();
    _session.close();
    _library.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _session),
        BlocProvider.value(value: _library),
      ],
      child: BlocListener<SessionCubit, SessionState>(
        // Load the library once per signed-in user; drop it on sign-out.
        listenWhen: (a, b) => _userId(a) != _userId(b),
        listener: (_, state) {
          final id = _userId(state);
          id == null ? _library.clear() : _library.load(id);
          // Recently viewed books are per device; don't show them to the next account.
          if (state is SignedOut) sl<RecentSearchesStore>().clear();
        },
        child: MaterialApp.router(
          title: 'Bookmarkd',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(fontFamily: widget.fontFamily),
          themeMode: ThemeMode.light,
          routerConfig: _router,
        ),
      ),
    );
  }

  static String? _userId(SessionState s) => switch (s) {
    SignedIn(:final profile) => profile.id,
    _ => null,
  };
}
