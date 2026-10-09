import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/feature/auth/data/repositories/authentication_repository_impl.dart';
import 'package:go_habit/feature/auth/domain/models/auth_failure.dart';
import 'package:go_habit/feature/auth/view/auth_validators.dart';
import 'package:go_habit/l10n/app_localizations_en.dart';
import 'package:go_habit/l10n/app_localizations_ru.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('mapAuthError', () {
    final cases = <String, (Object, AuthFailure)>{
      'wrong credentials': (
        const AuthApiException('Invalid login credentials', statusCode: '400', code: 'invalid_credentials'),
        AuthFailure.invalidCredentials,
      ),
      'unconfirmed email': (
        const AuthApiException('Email not confirmed', statusCode: '400', code: 'email_not_confirmed'),
        AuthFailure.emailNotConfirmed,
      ),
      'existing account': (
        const AuthApiException('User already registered', statusCode: '422', code: 'user_already_exists'),
        AuthFailure.userAlreadyExists,
      ),
      'email rate limit (the 429 seen on sign-up)': (
        const AuthApiException('email rate limit exceeded', statusCode: '429', code: 'over_email_send_rate_limit'),
        AuthFailure.rateLimited,
      ),
      '429 without a code': (const AuthApiException('Too many requests', statusCode: '429'), AuthFailure.rateLimited),
      'weak password': (
        AuthWeakPasswordException(message: 'weak', statusCode: '422', reasons: const ['characters']),
        AuthFailure.weakPassword,
      ),
      'same password': (
        const AuthApiException('same', statusCode: '422', code: 'same_password'),
        AuthFailure.samePassword,
      ),
      'sign-up disabled': (
        const AuthApiException('Signups not allowed', statusCode: '422', code: 'signup_disabled'),
        AuthFailure.signupDisabled,
      ),
      // Errors from a callback URL carry error_code in statusCode and error in code.
      'expired email link': (
        const AuthException('Email link is invalid or has expired', statusCode: 'otp_expired', code: 'access_denied'),
        AuthFailure.linkInvalid,
      ),
      'link opened on another device': (
        const AuthPKCEGrantCodeExchangeError('Code verifier could not be found'),
        AuthFailure.linkInvalid,
      ),
      'recovery session gone': (AuthSessionMissingException(), AuthFailure.sessionExpired),
      'retryable fetch': (AuthRetryableFetchException(), AuthFailure.network),
      'socket': (const SocketException('no route'), AuthFailure.network),
      'timeout': (TimeoutException('slow'), AuthFailure.network),
      'http client': (http.ClientException('closed'), AuthFailure.network),
      'unknown code': (const AuthApiException('?', statusCode: '500', code: 'unexpected_failure'), AuthFailure.unknown),
      'non-auth error': (StateError('bug'), AuthFailure.unknown),
    };

    for (final MapEntry(key: name, value: (error, expected)) in cases.entries) {
      test(name, () => expect(mapAuthError(error), expected));
    }

    test('a bare 400 uses the operation-specific fallback', () {
      const error = AuthApiException('Invalid login credentials', statusCode: '400');
      expect(mapAuthError(error), AuthFailure.unknown);
      expect(mapAuthError(error, badRequest: AuthFailure.invalidCredentials), AuthFailure.invalidCredentials);
    });
  });

  group('failure messages', () {
    test('every failure has a non-empty message in both languages', () {
      for (final l10n in [AppLocalizationsRu(), AppLocalizationsEn()]) {
        final messages = AuthFailure.values.map((failure) => failure.message(l10n)).toList();
        expect(messages, everyElement(isNotEmpty));
        expect(messages.toSet(), hasLength(messages.length), reason: 'messages must be distinct');
      }
    });

    test('messages never contain backend details', () {
      final l10n = AppLocalizationsEn();
      for (final failure in AuthFailure.values) {
        expect(failure.message(l10n), isNot(matches(RegExp('exception|status|code|429', caseSensitive: false))));
      }
    });
  });
}
