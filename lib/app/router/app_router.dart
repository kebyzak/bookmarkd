import 'dart:async';

import 'package:bookmarkd/features/auth/presentation/pages/auth_pages.dart';
import 'package:bookmarkd/features/auth/presentation/pages/splash_page.dart';
import 'package:bookmarkd/features/auth/presentation/session_cubit.dart';
import 'package:bookmarkd/features/books/presentation/author_page.dart';
import 'package:bookmarkd/features/books/presentation/book_details_page.dart';
import 'package:bookmarkd/features/home/presentation/home_page.dart';
import 'package:bookmarkd/features/library/presentation/library_page.dart';
import 'package:bookmarkd/features/onboarding/presentation/onboarding_page.dart';
import 'package:bookmarkd/features/profile/presentation/edit_profile_page.dart';
import 'package:bookmarkd/features/profile/presentation/profile_page.dart';
import 'package:bookmarkd/features/profile/presentation/readers_page.dart';
import 'package:bookmarkd/features/reading/presentation/reading_progress_page.dart';
import 'package:bookmarkd/features/reviews/presentation/write_review_page.dart';
import 'package:bookmarkd/features/search/presentation/search_page.dart';
import 'package:bookmarkd/features/social/presentation/activity_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_shell.dart';
import 'redirect.dart';

abstract final class Routes {
  static String book(String key) => '/book/${Uri.encodeComponent(key)}';

  static String progress(String key) => '${book(key)}/progress';

  static String review(String key) => '${book(key)}/review';

  static String user(String id) => '/users/$id';

  static String followers(String id) => '${user(id)}/followers';

  static String following(String id) => '${user(id)}/following';

  static String author(String name) => '/authors/${Uri.encodeComponent(name)}';
  static const editProfile = '/profile/edit';
  static const notifications = '/notifications';
}

final _rootKey = GlobalKey<NavigatorState>();

GoRouter createRouter(SessionCubit session, {required Listenable refresh}) {
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
          _branch('/library', const LibraryPage()),
          _branch('/search', const SearchPage()),
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
      GoRoute(path: '/activity', builder: (_, _) => const ActivityPage()),
      GoRoute(
        path: Routes.notifications,
        builder: (_, _) => const ReadersPage(list: ReaderList.notifications),
      ),
      GoRoute(
        path: '/authors/:name',
        builder: (_, s) => AuthorPage(name: s.pathParameters['name']!),
      ),
      GoRoute(
        path: '/users/:userId',
        builder: (_, s) => ProfilePage(userId: s.pathParameters['userId']),
        routes: [
          GoRoute(
            path: 'followers',
            builder: (_, s) => ReadersPage(list: ReaderList.followers, userId: s.pathParameters['userId']),
          ),
          GoRoute(
            path: 'following',
            builder: (_, s) => ReadersPage(list: ReaderList.following, userId: s.pathParameters['userId']),
          ),
        ],
      ),
    ],
  );
}

StatefulShellBranch _branch(String path, Widget page) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (_, _) => page)],
);

class StreamListenable extends ChangeNotifier {
  StreamListenable(Stream<Object?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
