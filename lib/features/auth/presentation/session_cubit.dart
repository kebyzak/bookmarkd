import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/repositories.dart';
import '../../profile/domain/profile.dart';

sealed class SessionState extends Equatable {
  const SessionState();
  @override
  List<Object?> get props => [];
}

class SessionUnknown extends SessionState {
  const SessionUnknown();
}

class SignedOut extends SessionState {
  const SignedOut();
}

class SignedIn extends SessionState {
  const SignedIn(this.profile);
  final Profile profile;

  bool get needsOnboarding => !profile.onboarded;

  @override
  List<Object?> get props => [profile];
}

/// Signed in, but the profile could not be loaded.
class SessionFailure extends SessionState {
  const SessionFailure(this.userId, this.message);
  final String userId;
  final String message;

  @override
  List<Object?> get props => [userId, message];
}

/// Owns "who is signed in" for the whole app.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._auth, this._profiles) : super(const SessionUnknown()) {
    _sub = _auth.userIdChanges().listen(_onUser);
  }

  final AuthRepository _auth;
  final ProfileRepository _profiles;
  late final StreamSubscription<String?> _sub;

  Profile? get profile => switch (state) {
    SignedIn(:final profile) => profile,
    _ => null,
  };

  Future<void> _onUser(String? userId) async {
    if (userId == null) return emit(const SignedOut());
    try {
      emit(SignedIn(await _profiles.getProfile(userId)));
    } catch (e) {
      emit(SessionFailure(userId, AppFailure.from(e).message));
    }
  }

  Future<void> retry() async {
    if (state case SessionFailure(:final userId)) await _onUser(userId);
  }

  void profileUpdated(Profile profile) => emit(SignedIn(profile));

  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
