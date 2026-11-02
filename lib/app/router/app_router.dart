import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/auth_pages.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/session_cubit.dart';
import '../../features/books/presentation/book_details_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/library/presentation/library_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/profile/presentation/edit_profile_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/reading/presentation/reading_progress_page.dart';
import '../../features/reviews/presentation/write_review_page.dart';
import '../../features/search/presentation/search_page.dart';
import '../../features/social/presentation/activity_page.dart';
import 'app_shell.dart';
import 'redirect.dart';

/// Route builders kept in one place so screens never hand-build paths.
abstract final class Routes {
  static String book(String key) => '/book/${Uri.encodeComponent(key)}';
  static String progress(String key) => '${book(key)}/progress';
  static String review(String key) => '${book(key)}/review';
  static String user(String id) => '/users/$id';
  static const editProfile = '/profile/edit';
}

final _rootKey = GlobalKey<NavigatorState>();

GoRouter createRouter(SessionCubit session) {
  final refresh = _StreamListenable(session.stream);
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (_, state) => redirectFor(session.state, state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomePage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordPage()),
      GoRoute(path: '/reset-password', builder: (_, _) => const ResetPasswordPage()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          _branch('/home', const HomePage()),
          _branch('/search', const SearchPage()),
          _branch('/library', const LibraryPage()),
          _branch('/activity', const ActivityPage()),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfilePage(),
                routes: [
                  GoRoute(path: 'edit', parentNavigatorKey: _rootKey, builder: (_, _) => const EditProfilePage()),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/book/:bookKey',
        builder: (_, s) => BookDetailsPage(bookKey: s.pathParameters['bookKey']!),
        routes: [
          GoRoute(
            path: 'progress',
            builder: (_, s) => ReadingProgressPage(bookKey: s.pathParameters['bookKey']!),
          ),
          GoRoute(
            path: 'review',
            builder: (_, s) => WriteReviewPage(bookKey: s.pathParameters['bookKey']!),
          ),
        ],
      ),
      GoRoute(
        path: '/users/:userId',
        builder: (_, s) => ProfilePage(userId: s.pathParameters['userId']),
      ),
    ],
  );
}

StatefulShellBranch _branch(String path, Widget page) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (_, _) => page)],
);

class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
