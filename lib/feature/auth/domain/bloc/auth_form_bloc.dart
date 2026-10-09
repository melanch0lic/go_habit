import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/feature/auth/domain/models/auth_failure.dart';
import 'package:go_habit/feature/auth/domain/repositories/i_authentication_repository.dart';

part 'auth_form_event.dart';
part 'auth_form_state.dart';

/// Submits one authentication form (sign-in, sign-up, password reset).
///
/// Each auth screen owns its instance, so a failed form never touches the app-wide
/// session state in `AuthBloc`. A successful sign-in is not navigated from here: the
/// router reacts to the new session.
class AuthFormBloc extends Bloc<AuthFormEvent, AuthFormState> {
  final IAuthenticationRepository _repository;

  AuthFormBloc(this._repository) : super(const AuthFormState()) {
    on<AuthFormFailureDismissed>((event, emit) {
      if (state.failure != null) emit(const AuthFormState());
    });
    // A request that is already running wins: repeated taps are dropped.
    on<_AuthFormSubmission>(_onSubmitted, transformer: droppable());
  }

  Future<void> _onSubmitted(_AuthFormSubmission event, Emitter<AuthFormState> emit) async {
    emit(const AuthFormState(status: AuthFormStatus.submitting));
    try {
      final success = switch (event) {
        AuthFormSignInSubmitted(:final email, :final password) =>
          await _repository.signInWithEmail(email: email, password: password).then((_) => AuthFormSuccess.signedIn),
        AuthFormSignUpSubmitted(:final email, :final password) => switch (
              await _repository.signUp(email: email, password: password)) {
            SignUpResult.signedIn => AuthFormSuccess.signedIn,
            SignUpResult.confirmationRequired => AuthFormSuccess.confirmationRequired,
          },
        AuthFormConfirmationResent(:final email) =>
          await _repository.resendSignUpConfirmation(email: email).then((_) => AuthFormSuccess.confirmationResent),
        AuthFormPasswordResetRequested(:final email) =>
          await _repository.requestPasswordReset(email: email).then((_) => AuthFormSuccess.resetEmailSent),
        AuthFormNewPasswordSubmitted(:final password) =>
          await _repository.updatePassword(password: password).then((_) => AuthFormSuccess.passwordUpdated),
      };
      emit(AuthFormState(status: AuthFormStatus.success, success: success));
    } on AuthFailureException catch (e) {
      emit(AuthFormState(status: AuthFormStatus.failure, failure: e.failure));
    } on Object {
      // Loading must always end, even for an error the repository did not map.
      emit(const AuthFormState(status: AuthFormStatus.failure, failure: AuthFailure.unknown));
    }
  }
}
