import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/router/app_router.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent, AuthState;

void main() {
  final login = AuthRoutes.login.path;
  final register = AuthRoutes.register.path;
  final forgot = AuthRoutes.forgotPassword.path;
  final reset = AuthRoutes.resetPassword.path;
  final home = HomeRoutes.home.path;
  final profile = ProfileRoutes.profile.path;

  group('resolveAuthRedirect', () {
    test('the splash screen decides on its own', () {
      expect(resolveAuthRedirect(location: '/', isSignedIn: false), isNull);
      expect(resolveAuthRedirect(location: '/', isSignedIn: true), isNull);
    });

    test('signed-out users stay on the auth screens', () {
      for (final location in [login, register, forgot]) {
        expect(resolveAuthRedirect(location: location, isSignedIn: false), isNull, reason: location);
      }
    });

    test('signed-out users cannot open the app or the new-password screen', () {
      for (final location in [home, profile, reset]) {
        expect(resolveAuthRedirect(location: location, isSignedIn: false), login, reason: location);
      }
    });

    test('signed-in users skip the sign-in screens', () {
      for (final location in [login, register, forgot]) {
        expect(resolveAuthRedirect(location: location, isSignedIn: true), home, reason: location);
      }
      expect(resolveAuthRedirect(location: profile, isSignedIn: true), isNull);
    });

    test('a reset link opens the new-password screen', () {
      expect(resolveAuthRedirect(location: login, isSignedIn: true, passwordRecovery: true), reset);
      expect(resolveAuthRedirect(location: home, isSignedIn: true, passwordRecovery: true), reset);
      expect(resolveAuthRedirect(location: reset, isSignedIn: true, passwordRecovery: true), isNull);
      // The link launched the app: the splash screen must not swallow it.
      expect(resolveAuthRedirect(location: '/', isSignedIn: true, passwordRecovery: true), reset);
    });

    test('the new-password screen can be left once open', () {
      expect(resolveAuthRedirect(location: reset, isSignedIn: true), isNull);
      expect(resolveAuthRedirect(location: home, isSignedIn: true), isNull);
    });
  });

  group('AuthRefreshListenable', () {
    test('notifies on every auth change and remembers a password recovery once', () async {
      final changes = StreamController<AuthState>();
      final listenable = AuthRefreshListenable(changes.stream);
      var notifications = 0;
      listenable.addListener(() => notifications++);

      changes.add(AuthState(AuthChangeEvent.signedIn, null));
      await pumpEventQueue();
      expect(notifications, 1);
      expect(listenable.takePasswordRecovery(), isFalse);

      changes.add(AuthState(AuthChangeEvent.passwordRecovery, null));
      await pumpEventQueue();
      expect(notifications, 2);
      expect(listenable.takePasswordRecovery(), isTrue);
      expect(listenable.takePasswordRecovery(), isFalse);

      listenable.dispose();
      await changes.close();
    });

    test('ignores stream errors from failed email links', () async {
      final changes = StreamController<AuthState>();
      final listenable = AuthRefreshListenable(changes.stream);

      changes.addError(Exception('otp_expired'));
      await pumpEventQueue();
      changes.add(AuthState(AuthChangeEvent.signedOut, null));
      await pumpEventQueue();

      expect(listenable.takePasswordRecovery(), isFalse);
      listenable.dispose();
      await changes.close();
    });
  });
}
