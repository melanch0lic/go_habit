import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/router/app_router.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/feature/auth/domain/bloc/auth_bloc.dart';
import 'package:go_habit/feature/auth/domain/models/auth_failure.dart';
import 'package:go_habit/feature/auth/domain/repositories/i_authentication_repository.dart';
import 'package:go_habit/feature/auth/view/auth_screen.dart';
import 'package:go_habit/feature/auth/view/components/components.dart';
import 'package:go_habit/feature/auth/view/forgot_password_screen.dart';
import 'package:go_habit/feature/auth/view/registration_screen.dart';
import 'package:go_habit/feature/auth/view/reset_password_screen.dart';
import 'package:go_habit/l10n/app_localizations.dart';
import 'package:go_habit/l10n/app_localizations_ru.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase show AuthChangeEvent, AuthState;

import '../../helpers/fake_auth_repository.dart';

final l10n = AppLocalizationsRu();

/// The auth routes of the app with a stub home screen, driven by the production
/// redirect and fed by the fake repository's session changes.
class _Harness {
  final repository = FakeAuthRepository();
  final authEvents = StreamController<supabase.AuthState>.broadcast();
  late final AuthBloc authBloc;
  late final AuthRefreshListenable refresh;
  late final GoRouter router;

  _Harness({String initialLocation = '/auth_routes/login', bool signedIn = false}) {
    if (signedIn) repository.signedIn = testUser;
    authBloc = AuthBloc(repository, FakeSessionData(repository.log))..add(AuthInitialCheckRequested());
    repository.users.stream.listen(
      (user) => authEvents.add(supabase.AuthState(
        user == null ? supabase.AuthChangeEvent.signedOut : supabase.AuthChangeEvent.signedIn,
        null,
      )),
      onError: (Object _) {},
    );
    refresh = AuthRefreshListenable(authEvents.stream);
    router = GoRouter(
      initialLocation: initialLocation,
      refreshListenable: refresh,
      redirect: (context, state) => resolveAuthRedirect(
        location: state.matchedLocation,
        isSignedIn: repository.signedIn != null,
        passwordRecovery: refresh.takePasswordRecovery(),
      ),
      routes: [
        GoRoute(path: AuthRoutes.login.path, builder: (_, __) => const AuthScreen()),
        GoRoute(path: AuthRoutes.register.path, builder: (_, __) => const RegistrationScreen()),
        GoRoute(
          path: AuthRoutes.forgotPassword.path,
          builder: (_, state) => ForgotPasswordScreen(initialEmail: state.extra as String? ?? ''),
        ),
        GoRoute(path: AuthRoutes.resetPassword.path, builder: (_, __) => const ResetPasswordScreen()),
        GoRoute(path: HomeRoutes.home.path, builder: (_, __) => const Scaffold(body: Text('HOME'))),
      ],
    );
  }

  Widget build() => RepositoryProvider<IAuthenticationRepository>.value(
        value: repository,
        child: BlocProvider.value(
          value: authBloc,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.defaultTheme.lightTheme,
            locale: const Locale('ru'),
            supportedLocales: const [Locale('ru'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          ),
        ),
      );

  /// Closing is not awaited: it would never complete inside the fake async zone.
  void dispose() {
    authBloc.close();
    router.dispose();
    refresh.dispose();
    authEvents.close();
    repository.dispose();
  }
}

Future<_Harness> _pump(WidgetTester tester,
    {String initialLocation = '/auth_routes/login', bool signedIn = false}) async {
  final harness = _Harness(initialLocation: initialLocation, signedIn: signedIn);
  addTearDown(harness.dispose);
  await tester.pumpWidget(harness.build());
  await tester.pumpAndSettle();
  return harness;
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Finder get _submitButton => find.byType(AuthSubmitButton);

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(_submitButton);
  await tester.tap(_submitButton);
  await tester.pump();
}

void main() {
  group('sign-in', () {
    testWidgets('validates fields inline without calling the backend', (tester) async {
      final harness = await _pump(tester);

      await _tapSubmit(tester);
      expect(find.text(l10n.email_required), findsOneWidget);
      expect(find.text(l10n.password_required), findsOneWidget);

      await tester.enterText(_field(l10n.email_label), 'not-an-email');
      await tester.pump();
      expect(find.text(l10n.email_invalid), findsOneWidget);
      expect(harness.repository.log, isEmpty);
    });

    testWidgets('toggling password visibility keeps the text', (tester) async {
      await _pump(tester);
      await tester.enterText(_field(l10n.password_label), 'secret1');

      EditableText editable() => tester
          .widget<EditableText>(find.descendant(of: _field(l10n.password_label), matching: find.byType(EditableText)));
      expect(editable().obscureText, isTrue);

      await tester.tap(find.byTooltip(l10n.password_show));
      await tester.pump();
      expect(editable().obscureText, isFalse);
      expect(editable().controller.text, 'secret1');

      await tester.tap(find.byTooltip(l10n.password_hide));
      await tester.pump();
      expect(editable().obscureText, isTrue);
    });

    testWidgets('a successful sign-in opens the app through the router', (tester) async {
      final harness = await _pump(tester);
      await tester.enterText(_field(l10n.email_label), ' user@example.com ');
      await tester.enterText(_field(l10n.password_label), 'habit1');
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(harness.repository.log, ['signIn:user@example.com'], reason: 'email is trimmed');
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('shows progress and ignores repeated submissions while signing in', (tester) async {
      final harness = await _pump(tester);
      harness.repository.gate = Completer<void>();
      await tester.enterText(_field(l10n.email_label), 'user@example.com');
      await tester.enterText(_field(l10n.password_label), 'habit1');

      await _tapSubmit(tester);
      expect(find.descendant(of: _submitButton, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
      expect(tester.widget<TextFormField>(_field(l10n.password_label)).enabled, isFalse);

      await tester.tap(_submitButton, warnIfMissed: false);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(harness.repository.requestCount, 1);

      harness.repository.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('explains a failure and hides it once the user edits a field', (tester) async {
      final harness = await _pump(tester);
      harness.repository.failure = AuthFailure.invalidCredentials;
      await tester.enterText(_field(l10n.email_label), 'user@example.com');
      await tester.enterText(_field(l10n.password_label), 'wrong1');
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text(l10n.auth_error_invalid_credentials), findsOneWidget);
      expect(find.text('HOME'), findsNothing);
      expect(find.descendant(of: _submitButton, matching: find.byType(CircularProgressIndicator)), findsNothing);

      await tester.enterText(_field(l10n.password_label), 'wrong12');
      await tester.pumpAndSettle();
      expect(find.text(l10n.auth_error_invalid_credentials), findsNothing);
    });

    testWidgets('reports an expired email link', (tester) async {
      final harness = await _pump(tester);
      harness.repository.users.addError(const AuthFailureException(AuthFailure.linkInvalid));
      await tester.pumpAndSettle();

      expect(find.text(l10n.auth_error_link_invalid), findsOneWidget);
      expect(find.text('HOME'), findsNothing);
    });

    testWidgets('signed-in users never see the sign-in screen', (tester) async {
      await _pump(tester, signedIn: true);
      expect(find.text('HOME'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('registration opens on top of sign-in and returns with back', (tester) async {
      await _pump(tester);

      await tester.tap(find.text(l10n.auth_create_account_action));
      await tester.pumpAndSettle();
      expect(find.text(l10n.create_account), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text(l10n.welcome_back), findsOneWidget);

      await tester.tap(find.text(l10n.auth_create_account_action));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l10n.sign_in));
      await tester.tap(find.text(l10n.sign_in));
      await tester.pumpAndSettle();
      expect(find.text(l10n.welcome_back), findsOneWidget);
    });

    testWidgets('password recovery takes the typed email along', (tester) async {
      await _pump(tester);
      await tester.enterText(_field(l10n.email_label), 'user@example.com');

      await tester.tap(find.text(l10n.auth_forgot_password));
      await tester.pumpAndSettle();

      expect(find.text(l10n.auth_reset_title), findsOneWidget);
      final email = tester.widget<TextFormField>(_field(l10n.email_label));
      expect(email.controller!.text, 'user@example.com');
    });
  });

  group('registration', () {
    Future<void> fillForm(WidgetTester tester, {String password = 'habit1', String? confirm}) async {
      await tester.enterText(_field(l10n.email_label), 'new@example.com');
      await tester.enterText(_field(l10n.password_label), password);
      await tester.enterText(_field(l10n.confirm_password_label), confirm ?? password);
    }

    testWidgets('applies the password rules', (tester) async {
      final harness = await _pump(tester, initialLocation: AuthRoutes.register.path);

      await fillForm(tester, password: 'abcdefgh');
      await _tapSubmit(tester);
      expect(find.text(l10n.password_letters_digits), findsOneWidget);

      await fillForm(tester, confirm: 'habit2');
      await tester.pump();
      expect(find.text(l10n.passwords_dont_match), findsOneWidget);
      expect(harness.repository.log, isEmpty);
    });

    testWidgets('with email confirmation shows next steps and stays signed out', (tester) async {
      final harness = await _pump(tester, initialLocation: AuthRoutes.register.path);
      await fillForm(tester);
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text(l10n.auth_check_email_title), findsOneWidget);
      expect(find.text(l10n.auth_confirm_email_message('new@example.com')), findsOneWidget);
      expect(find.text('HOME'), findsNothing);
      expect(harness.repository.signedIn, isNull);

      // Resending is possible only after the cooldown.
      final resend = find.widgetWithText(TextButton, l10n.auth_resend_in(60));
      expect(tester.widget<TextButton>(resend).onPressed, isNull);
      await tester.pump(EmailSentPanel.resendCooldown);
      await tester.tap(find.text(l10n.auth_resend_email));
      await tester.pumpAndSettle();
      expect(harness.repository.log, ['signUp:new@example.com', 'resend:new@example.com']);
      expect(find.text(l10n.auth_email_resent), findsOneWidget);

      await tester.tap(find.text(l10n.auth_back_to_sign_in));
      await tester.pumpAndSettle();
      expect(find.text(l10n.welcome_back), findsOneWidget);
    });

    testWidgets('without email confirmation opens the app', (tester) async {
      final harness = await _pump(tester, initialLocation: AuthRoutes.register.path);
      harness.repository.signUpResult = SignUpResult.signedIn;
      await fillForm(tester);
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('explains rate limiting', (tester) async {
      final harness = await _pump(tester, initialLocation: AuthRoutes.register.path);
      harness.repository.failure = AuthFailure.rateLimited;
      await fillForm(tester);
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text(l10n.auth_error_rate_limited), findsOneWidget);
      expect(find.text(l10n.create_account), findsOneWidget);
    });
  });

  group('password recovery', () {
    testWidgets('confirms without revealing whether the account exists', (tester) async {
      final harness = await _pump(tester, initialLocation: AuthRoutes.forgotPassword.path);
      await tester.enterText(_field(l10n.email_label), 'someone@example.com');
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(harness.repository.log, ['reset:someone@example.com']);
      expect(find.text(l10n.auth_reset_sent_message('someone@example.com')), findsOneWidget);
    });

    testWidgets('a network failure keeps the form for another try', (tester) async {
      final harness = await _pump(tester, initialLocation: AuthRoutes.forgotPassword.path);
      harness.repository.failure = AuthFailure.network;
      await tester.enterText(_field(l10n.email_label), 'someone@example.com');
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text(l10n.auth_error_network), findsOneWidget);
      expect(find.text(l10n.auth_reset_title), findsOneWidget);
    });

    testWidgets('a reset link opens the new-password screen and saving opens the app', (tester) async {
      final harness = await _pump(tester);

      // The link signs the user in with a recovery session.
      harness.repository.signedIn = testUser;
      harness.authEvents.add(supabase.AuthState(supabase.AuthChangeEvent.passwordRecovery, null));
      await tester.pumpAndSettle();
      expect(find.text(l10n.auth_new_password_title), findsOneWidget);

      await tester.enterText(_field(l10n.auth_new_password_label), 'habit2');
      await tester.enterText(_field(l10n.confirm_password_label), 'habit2');
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(harness.repository.log, ['updatePassword']);
      expect(find.text('HOME'), findsOneWidget);
      expect(find.text(l10n.auth_password_updated), findsOneWidget);
    });

    testWidgets('the new-password screen is closed to signed-out users', (tester) async {
      await _pump(tester, initialLocation: AuthRoutes.resetPassword.path);
      expect(find.text(l10n.welcome_back), findsOneWidget);
    });
  });

  group('layout', () {
    for (final route in [
      AuthRoutes.login.path,
      AuthRoutes.register.path,
      AuthRoutes.forgotPassword.path,
    ]) {
      testWidgets('$route fits a small phone with the keyboard open and large text', (tester) async {
        tester.view
          ..physicalSize = const Size(320, 568)
          ..devicePixelRatio = 1
          ..viewInsets = const FakeViewPadding(bottom: 260);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await _pump(tester, initialLocation: route);
        await _tapSubmit(tester); // shows every validation message
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        await tester.ensureVisible(_submitButton);
        await tester.pumpAndSettle();
        expect(tester.getRect(_submitButton).bottom, lessThanOrEqualTo(568 - 260));
      });
    }
  });
}
