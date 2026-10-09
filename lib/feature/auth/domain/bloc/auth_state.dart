part of 'auth_bloc.dart';

sealed class AuthState {}

class AuthInitial extends AuthState {}

class AuthUserAuthenticated extends AuthState {
  final User user;

  AuthUserAuthenticated(this.user);
}

/// Still signed in: sign-out is on hold because [pendingChanges] local changes have
/// not reached the server.
class AuthLogoutConfirmationRequired extends AuthUserAuthenticated {
  final int pendingChanges;

  AuthLogoutConfirmationRequired(super.user, {required this.pendingChanges});
}

class AuthUserUnauthenticated extends AuthState {
  /// Set when an email link failed; the sign-in screen explains what happened.
  final AuthFailure? failure;

  AuthUserUnauthenticated({this.failure});
}

class AuthError extends AuthState {
  final String errorMessage;

  AuthError(this.errorMessage);
}
