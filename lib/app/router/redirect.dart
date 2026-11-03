import 'package:bookmarkd/features/auth/presentation/session_cubit.dart';

const authRoutes = {'/welcome', '/login', '/register', '/forgot-password'};

String? redirectFor(SessionState session, String location) {
  final onAuth = authRoutes.contains(location);
  return switch (session) {
    SignedIn(recoveringPassword: true) => location == '/reset-password' ? null : '/reset-password',
    SessionUnknown() || SessionFailure() => location == '/splash' ? null : '/splash',
    SignedOut() => onAuth ? null : '/welcome',
    SignedIn(needsOnboarding: true) => location == '/onboarding' ? null : '/onboarding',
    SignedIn() => onAuth || location == '/onboarding' || location == '/splash' ? '/home' : null,
  };
}
