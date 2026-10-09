/// Why an authentication request failed, independent of the backend SDK.
///
/// The presentation layer turns it into a localized message; raw backend messages are
/// never shown to the user.
enum AuthFailure {
  invalidCredentials,
  emailNotConfirmed,
  userAlreadyExists,
  weakPassword,
  samePassword,
  invalidEmail,
  signupDisabled,
  rateLimited,
  network,

  /// An email link (confirmation or password reset) is expired, already used or was
  /// opened on another device.
  linkInvalid,

  /// The session needed for the operation is gone, e.g. the recovery session expired.
  sessionExpired,
  unknown,
}

/// Thrown by authentication repository implementations.
final class AuthFailureException implements Exception {
  final AuthFailure failure;

  const AuthFailureException(this.failure);

  @override
  String toString() => 'AuthFailureException($failure)';
}

/// Outcome of a successful sign-up request.
enum SignUpResult {
  /// The account is active and a session was created.
  signedIn,

  /// The project requires email confirmation; no session exists yet.
  confirmationRequired,
}
