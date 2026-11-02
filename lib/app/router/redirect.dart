import '../../features/auth/presentation/session_cubit.dart';

const authRoutes = {'/welcome', '/login', '/register', '/forgot-password'};

/// The one place that decides where a session may be. Pure.
String? redirectFor(SessionState session, String location) {
  final onAuth = authRoutes.contains(location);
  return switch (session) {
    SessionUnknown() || SessionFailure() => location == '/splash' ? null : '/splash',
    SignedOut() => onAuth ? null : '/welcome',
    SignedIn(needsOnboarding: true) => location == '/onboarding' ? null : '/onboarding',
    SignedIn() => onAuth || location == '/onboarding' || location == '/splash' ? '/home' : null,
  };
}
