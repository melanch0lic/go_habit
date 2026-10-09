part of 'auth_bloc.dart';

sealed class AuthEvent {}

class AuthInitialCheckRequested extends AuthEvent {}

class AuthOnCurrentUserChanged extends AuthEvent {
  final User? user;

  AuthOnCurrentUserChanged(this.user);
}

class AuthLogoutButtonPressed extends AuthEvent {
  /// Sign out even if local changes could not be synced (they are discarded).
  final bool force;

  AuthLogoutButtonPressed({this.force = false});
}

class AuthErrorOccurred extends AuthEvent {
  final AuthFailure failure;

  AuthErrorOccurred(this.failure);
}
