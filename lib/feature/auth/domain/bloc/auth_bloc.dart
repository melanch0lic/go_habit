import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/sync/sync_service.dart';
import 'package:go_habit/feature/auth/domain/models/auth_failure.dart';
import 'package:go_habit/feature/auth/domain/repositories/i_authentication_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final IAuthenticationRepository _authenticationRepository;
  final SessionDataManager _sessionData;
  StreamSubscription<User?>? _userSubscription;

  AuthBloc(this._authenticationRepository, this._sessionData) : super(AuthInitial()) {
    on<AuthEvent>((event, emit) async {
      switch (event) {
        case AuthInitialCheckRequested():
          await _onInitialAuthChecked(event, emit);
        case AuthOnCurrentUserChanged():
          await _onCurrentUserChanged(event, emit);
        case AuthLogoutButtonPressed():
          await _onLogoutButtonPressed(event, emit);
        case AuthErrorOccurred():
          _onAuthErrorOccurred(event, emit);
      }
    });

    _startUserSubscription();
  }

  Future<void> _onInitialAuthChecked(AuthInitialCheckRequested event, Emitter<AuthState> emit) async {
    final signedInUser = _authenticationRepository.getSignedInUser();
    signedInUser != null ? emit(AuthUserAuthenticated(signedInUser)) : emit(AuthUserUnauthenticated());
  }

  /// Local data is removed on sign-out so the next account never sees it. Unsynced
  /// changes would be lost, so they are uploaded first and, if that is not possible,
  /// the user has to confirm (`force`).
  Future<void> _onLogoutButtonPressed(AuthLogoutButtonPressed event, Emitter<AuthState> emit) async {
    final current = state;
    try {
      if (!event.force) {
        await _sessionData.syncNow();
        final pending = await _sessionData.pendingChangesCount();
        if (pending > 0 && current is AuthUserAuthenticated) {
          emit(AuthLogoutConfirmationRequired(current.user, pendingChanges: pending));
          return;
        }
      }
      try {
        await _authenticationRepository.signOut();
      } on Object catch (e) {
        // The SDK removes the local session before revoking it on the server, so the
        // user is signed out on this device even if the revoke request failed.
        debugPrint('Remote sign-out failed: $e');
      }
      await _sessionData.clearLocalData();
    } on Object catch (e) {
      debugPrint(e.toString());
      emit(AuthError('Ошибка выхода из системы'));
    }
  }

  Future<void> _onCurrentUserChanged(AuthOnCurrentUserChanged event, Emitter<AuthState> emit) async =>
      event.user != null ? emit(AuthUserAuthenticated(event.user!)) : emit(AuthUserUnauthenticated());

  void _startUserSubscription() => _userSubscription =
      _authenticationRepository.getCurrentUser().listen((user) => add(AuthOnCurrentUserChanged(user)))
        ..onError((Object error) {
          add(AuthErrorOccurred(error is AuthFailureException ? error.failure : AuthFailure.unknown));
        });

  /// Errors on the session stream come from email links that could not be exchanged
  /// for a session (expired, already used, opened on another device). They do not
  /// change the session, so a signed-in user is not affected.
  void _onAuthErrorOccurred(AuthErrorOccurred event, Emitter<AuthState> emit) {
    debugPrint('Auth callback failed: ${event.failure}');
    if (state is AuthUserAuthenticated) return;
    emit(AuthUserUnauthenticated(failure: event.failure));
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    return super.close();
  }
}
