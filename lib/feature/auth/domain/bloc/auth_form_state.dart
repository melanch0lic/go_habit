part of 'auth_form_bloc.dart';

enum AuthFormStatus { idle, submitting, success, failure }

enum AuthFormSuccess { signedIn, confirmationRequired, confirmationResent, resetEmailSent, passwordUpdated }

final class AuthFormState {
  final AuthFormStatus status;

  /// Set when [status] is [AuthFormStatus.failure].
  final AuthFailure? failure;

  /// Set when [status] is [AuthFormStatus.success].
  final AuthFormSuccess? success;

  const AuthFormState({this.status = AuthFormStatus.idle, this.failure, this.success});

  bool get isSubmitting => status == AuthFormStatus.submitting;
}
