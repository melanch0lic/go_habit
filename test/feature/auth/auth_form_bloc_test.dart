import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/feature/auth/domain/bloc/auth_form_bloc.dart';
import 'package:go_habit/feature/auth/domain/models/auth_failure.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late AuthFormBloc bloc;
  late List<AuthFormState> states;

  setUp(() {
    repository = FakeAuthRepository();
    bloc = AuthFormBloc(repository);
    states = [];
    bloc.stream.listen(states.add);
  });

  tearDown(() async {
    await bloc.close();
    await repository.dispose();
  });

  test('sign-in: loading, then success', () async {
    bloc.add(const AuthFormSignInSubmitted(email: 'a@b.co', password: 'habit1'));
    await pumpEventQueue();

    expect(states.map((s) => s.status), [AuthFormStatus.submitting, AuthFormStatus.success]);
    expect(states.last.success, AuthFormSuccess.signedIn);
    expect(repository.log, ['signIn:a@b.co']);
  });

  test('sign-in failure ends loading with the mapped failure', () async {
    repository.failure = AuthFailure.invalidCredentials;
    bloc.add(const AuthFormSignInSubmitted(email: 'a@b.co', password: 'wrong'));
    await pumpEventQueue();

    expect(states.map((s) => s.status), [AuthFormStatus.submitting, AuthFormStatus.failure]);
    expect(states.last.failure, AuthFailure.invalidCredentials);
  });

  test('repeated submissions while a request runs are dropped', () async {
    repository.gate = Completer<void>();
    for (var i = 0; i < 3; i++) {
      bloc.add(const AuthFormSignInSubmitted(email: 'a@b.co', password: 'habit1'));
    }
    await pumpEventQueue();
    expect(bloc.state.isSubmitting, isTrue);

    repository.gate!.complete();
    await pumpEventQueue();

    expect(repository.requestCount, 1);
    expect(bloc.state.success, AuthFormSuccess.signedIn);
  });

  test('sign-up with confirmation required does not claim a session', () async {
    repository.signUpResult = SignUpResult.confirmationRequired;
    bloc.add(const AuthFormSignUpSubmitted(email: 'a@b.co', password: 'habit1'));
    await pumpEventQueue();

    expect(bloc.state.success, AuthFormSuccess.confirmationRequired);
    expect(repository.signedIn, isNull);
  });

  test('sign-up without confirmation signs in', () async {
    repository.signUpResult = SignUpResult.signedIn;
    bloc.add(const AuthFormSignUpSubmitted(email: 'a@b.co', password: 'habit1'));
    await pumpEventQueue();

    expect(bloc.state.success, AuthFormSuccess.signedIn);
  });

  test('password reset and resend report their own success', () async {
    bloc.add(const AuthFormPasswordResetRequested(email: 'a@b.co'));
    await pumpEventQueue();
    expect(bloc.state.success, AuthFormSuccess.resetEmailSent);

    bloc.add(const AuthFormConfirmationResent(email: 'a@b.co'));
    await pumpEventQueue();
    expect(bloc.state.success, AuthFormSuccess.confirmationResent);

    bloc.add(const AuthFormNewPasswordSubmitted(password: 'habit2'));
    await pumpEventQueue();
    expect(bloc.state.success, AuthFormSuccess.passwordUpdated);
  });

  test('dismissing a failure returns to idle', () async {
    repository.failure = AuthFailure.network;
    bloc.add(const AuthFormPasswordResetRequested(email: 'a@b.co'));
    await pumpEventQueue();
    expect(bloc.state.failure, AuthFailure.network);

    bloc.add(const AuthFormFailureDismissed());
    await pumpEventQueue();
    expect(bloc.state.status, AuthFormStatus.idle);
    expect(bloc.state.failure, isNull);
  });
}
