import 'dart:async';
import 'dart:io';

import 'package:go_habit/feature/auth/domain/models/auth_failure.dart';
import 'package:go_habit/feature/auth/domain/repositories/i_authentication_repository.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Email links (sign-up confirmation, password reset) return to the app through this
/// URL. It must be listed in the project's Auth → URL Configuration → Redirect URLs;
/// otherwise Supabase falls back to the Site URL. See docs/BACKEND.md.
const authCallbackUrl = 'gohabit://auth-callback';

final class AuthenticationRepositoryImpl implements IAuthenticationRepository {
  final SupabaseClient _supabase;

  AuthenticationRepositoryImpl(this._supabase);

  @override
  Stream<User?> getCurrentUser() => _supabase.auth.onAuthStateChange
      .map((data) => data.session?.user)
      .handleError((Object error) => throw AuthFailureException(mapAuthError(error)));

  @override
  User? getSignedInUser() => _supabase.auth.currentUser;

  @override
  Future<void> signInWithEmail({required String email, required String password}) => _guard(
        () => _supabase.auth.signInWithPassword(email: email, password: password),
        // Older GoTrue versions answer wrong credentials with a bare 400.
        badRequest: AuthFailure.invalidCredentials,
      );

  @override
  Future<SignUpResult> signUp({required String email, required String password}) => _guard(() async {
        final response = await _supabase.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: authCallbackUrl,
        );
        // With confirmations enabled there is no session yet. For an already registered
        // address Supabase returns the same shape on purpose, so the caller must not
        // treat this as proof that a new account exists.
        return response.session != null ? SignUpResult.signedIn : SignUpResult.confirmationRequired;
      });

  @override
  Future<void> resendSignUpConfirmation({required String email}) => _guard(
        () => _supabase.auth.resend(type: OtpType.signup, email: email, emailRedirectTo: authCallbackUrl),
      );

  @override
  Future<void> requestPasswordReset({required String email}) => _guard(
        () => _supabase.auth.resetPasswordForEmail(email, redirectTo: authCallbackUrl),
      );

  @override
  Future<void> updatePassword({required String password}) => _guard(
        () => _supabase.auth.updateUser(UserAttributes(password: password)),
      );

  @override
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Ошибка выхода из системы: $e');
    }
  }

  Future<T> _guard<T>(Future<T> Function() request, {AuthFailure badRequest = AuthFailure.unknown}) async {
    try {
      return await request();
    } on Object catch (error) {
      throw AuthFailureException(mapAuthError(error, badRequest: badRequest));
    }
  }
}

/// Maps errors of the Supabase SDK to [AuthFailure].
///
/// Error codes: https://supabase.com/docs/guides/auth/debugging/error-codes.
/// [badRequest] is used for a 400 response without a code.
AuthFailure mapAuthError(Object error, {AuthFailure badRequest = AuthFailure.unknown}) {
  if (error is AuthFailureException) return error.failure;
  if (error is SocketException || error is TimeoutException || error is http.ClientException) {
    return AuthFailure.network;
  }
  if (error is AuthRetryableFetchException) return AuthFailure.network;
  if (error is AuthWeakPasswordException) return AuthFailure.weakPassword;
  if (error is AuthPKCEGrantCodeExchangeError) return AuthFailure.linkInvalid;
  if (error is AuthSessionMissingException) return AuthFailure.sessionExpired;
  if (error is! AuthException) return AuthFailure.unknown;

  // Errors parsed from a callback URL carry `error_code` in statusCode.
  final codes = {error.code, error.statusCode};
  bool has(String code) => codes.contains(code);

  if (has('invalid_credentials')) return AuthFailure.invalidCredentials;
  if (has('email_not_confirmed')) return AuthFailure.emailNotConfirmed;
  if (has('user_already_exists') || has('email_exists')) return AuthFailure.userAlreadyExists;
  if (has('weak_password')) return AuthFailure.weakPassword;
  if (has('same_password')) return AuthFailure.samePassword;
  if (has('email_address_invalid') || has('email_address_not_authorized')) return AuthFailure.invalidEmail;
  if (has('signup_disabled') || has('email_provider_disabled')) return AuthFailure.signupDisabled;
  if (has('over_email_send_rate_limit') || has('over_request_rate_limit') || has('429')) {
    return AuthFailure.rateLimited;
  }
  if (has('otp_expired') ||
      has('flow_state_expired') ||
      has('flow_state_not_found') ||
      has('bad_code_verifier') ||
      has('access_denied')) {
    return AuthFailure.linkInvalid;
  }
  if (has('session_not_found') || has('session_expired') || has('refresh_token_not_found')) {
    return AuthFailure.sessionExpired;
  }
  if (error.statusCode == '400' && error.code == null) return badRequest;
  return AuthFailure.unknown;
}
