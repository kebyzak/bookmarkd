import 'package:bookmarkd/app/router/redirect.dart';
import 'package:bookmarkd/features/auth/presentation/session_cubit.dart';
import 'package:bookmarkd/features/profile/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const onboarded = SignedIn(Profile(id: 'u', username: 'me', onboarded: true));
  const fresh = SignedIn(Profile(id: 'u'));

  test('unknown session waits on the splash', () {
    expect(redirectFor(const SessionUnknown(), '/home'), '/splash');
    expect(redirectFor(const SessionUnknown(), '/splash'), isNull);
  });

  test('signed-out users only see auth routes', () {
    expect(redirectFor(const SignedOut(), '/library'), '/welcome');
    expect(redirectFor(const SignedOut(), '/login'), isNull);
    expect(redirectFor(const SignedOut(), '/forgot-password'), isNull);
  });

  test('new users are sent to onboarding and kept there', () {
    expect(redirectFor(fresh, '/home'), '/onboarding');
    expect(redirectFor(fresh, '/onboarding'), isNull);
  });

  test('onboarded users skip auth screens but keep deep links', () {
    expect(redirectFor(onboarded, '/login'), '/home');
    expect(redirectFor(onboarded, '/onboarding'), '/home');
    expect(redirectFor(onboarded, '/book/gb:abc'), isNull);
  });
}
