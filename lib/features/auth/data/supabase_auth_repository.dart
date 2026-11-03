import 'package:bookmarkd/core/network/supabase_guard.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client, {required this.passwordResetRedirect});

  final SupabaseClient _client;
  final String passwordResetRedirect;

  GoTrueClient get _auth => _client.auth;

  @override
  String? get currentUserId => _auth.currentUser?.id;

  @override
  Stream<String?> userIdChanges() => _userIds().distinct();

  Stream<String?> _userIds() async* {
    yield currentUserId;
    yield* _auth.onAuthStateChange.map((event) => event.session?.user.id);
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      guardSupabase(() => _auth.signInWithPassword(email: email.trim(), password: password));

  @override
  Future<SignUpResult> signUp({required String email, required String password}) => guardSupabase(() async {
    final res = await _auth.signUp(email: email.trim(), password: password);
    return res.session == null ? SignUpResult.confirmEmail : SignUpResult.signedIn;
  });

  @override
  Future<void> sendPasswordReset(String email) => guardSupabase(
    () => _auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: passwordResetRedirect.isEmpty ? null : passwordResetRedirect,
    ),
  );

  @override
  Stream<void> passwordRecoveries() =>
      _auth.onAuthStateChange.where((e) => e.event == AuthChangeEvent.passwordRecovery).map((_) {});

  @override
  Future<void> updatePassword(String password) =>
      guardSupabase(() => _auth.updateUser(UserAttributes(password: password)));

  @override
  Future<void> signOut() => guardSupabase(() => _auth.signOut());
}
