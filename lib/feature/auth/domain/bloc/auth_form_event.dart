part of 'auth_form_bloc.dart';

sealed class AuthFormEvent {
  const AuthFormEvent();
}

/// Hides the current error, e.g. when the user edits a field.
final class AuthFormFailureDismissed extends AuthFormEvent {
  const AuthFormFailureDismissed();
}

/// A request to the backend; only one runs at a time.
sealed class _AuthFormSubmission extends AuthFormEvent {
  const _AuthFormSubmission();
}

final class AuthFormSignInSubmitted extends _AuthFormSubmission {
  final String email;
  final String password;

  const AuthFormSignInSubmitted({required this.email, required this.password});
}

final class AuthFormSignUpSubmitted extends _AuthFormSubmission {
  final String email;
  final String password;

  const AuthFormSignUpSubmitted({required this.email, required this.password});
}

final class AuthFormConfirmationResent extends _AuthFormSubmission {
  final String email;

  const AuthFormConfirmationResent({required this.email});
}

final class AuthFormPasswordResetRequested extends _AuthFormSubmission {
  final String email;

  const AuthFormPasswordResetRequested({required this.email});
}

final class AuthFormNewPasswordSubmitted extends _AuthFormSubmission {
  final String password;

  const AuthFormNewPasswordSubmitted({required this.password});
}
