import 'dart:async';

import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/features/profile/domain/profile.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  const SignedIn(this.profile, {this.recoveringPassword = false});

  final Profile profile;

  final bool recoveringPassword;

  bool get needsOnboarding => !profile.onboarded;

  @override
  List<Object?> get props => [profile, recoveringPassword];
}

class SessionFailure extends SessionState {
  const SessionFailure(this.userId, this.message);

  final String userId;
  final String message;

  @override
  List<Object?> get props => [userId, message];
}

class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._auth, this._profiles) : super(const SessionUnknown()) {
    _sub = _auth.userIdChanges().listen(_onUser);
    _recoverySub = _auth.passwordRecoveries().listen((_) {
      _recovering = true;
      if (state case SignedIn(:final profile)) emit(SignedIn(profile, recoveringPassword: true));
    });
  }

  final AuthRepository _auth;
  final ProfileRepository _profiles;
  late final StreamSubscription<String?> _sub;
  late final StreamSubscription<void> _recoverySub;

  bool _recovering = false;

  Profile? get profile => switch (state) {
    SignedIn(:final profile) => profile,
    _ => null,
  };

  Future<void> _onUser(String? userId) async {
    if (userId == null) return emit(const SignedOut());
    try {
      final profile = await _profiles.getProfile(userId);
      if (isClosed || _auth.currentUserId != userId) return;
      emit(SignedIn(profile, recoveringPassword: _recovering));
    } catch (e) {
      if (isClosed || _auth.currentUserId != userId) return;
      emit(SessionFailure(userId, AppFailure.from(e).message));
    }
  }

  Future<void> retry() async {
    if (state case SessionFailure(:final userId)) await _onUser(userId);
  }

  void profileUpdated(Profile profile) => emit(SignedIn(profile, recoveringPassword: _recovering));

  Future<void> updatePassword(String password) async {
    await _auth.updatePassword(password);
    _recovering = false;
    if (state case SignedIn(:final profile)) emit(SignedIn(profile));
  }

  Future<void> signOut() {
    _recovering = false;
    return _auth.signOut();
  }

  @override
  Future<void> close() {
    _sub.cancel();
    _recoverySub.cancel();
    return super.close();
  }
}
