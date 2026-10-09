import 'package:go_habit/feature/auth/domain/models/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Operations throw [AuthFailureException]; [getCurrentUser] reports failed email
/// links as [AuthFailureException] errors on the stream.
abstract interface class IAuthenticationRepository {
  Future<void> signInWithEmail({required String email, required String password});
  Future<SignUpResult> signUp({required String email, required String password});

  /// Sends the sign-up confirmation email again.
  Future<void> resendSignUpConfirmation({required String email});

  /// Sends a password reset link. Completes normally whether or not an account with
  /// this email exists, so the result never reveals registered addresses.
  Future<void> requestPasswordReset({required String email});

  /// Sets a new password for the signed-in user (after following a reset link).
  Future<void> updatePassword({required String password});
  Future<void> signOut();
  Stream<User?> getCurrentUser();
  User? getSignedInUser();
}
