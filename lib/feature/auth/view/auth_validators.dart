import 'package:go_habit/feature/auth/domain/models/auth_failure.dart';
import 'package:go_habit/l10n/app_localizations.dart';

/// Client-side checks that help the user fill the forms. The backend validates again;
/// these rules only mirror `supabase/config.toml` (6+ characters, letters and digits).
abstract final class AuthValidators {
  static const minPasswordLength = 6;

  // Deliberately permissive: one "@", no spaces, a dot in the domain. Plus addressing
  // and long TLDs are valid; the server has the final word.
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _letter = RegExp(r'\p{L}', unicode: true);
  static final _digit = RegExp(r'\d');

  /// Emails are compared case-insensitively by Supabase; spaces come from autofill.
  static String normalizeEmail(String value) => value.trim();

  static String? email(String? value, AppLocalizations l10n) {
    final email = normalizeEmail(value ?? '');
    if (email.isEmpty) return l10n.email_required;
    if (!_email.hasMatch(email)) return l10n.email_invalid;
    return null;
  }

  /// Sign-in only requires a value: accounts may predate the current rules.
  static String? existingPassword(String? value, AppLocalizations l10n) =>
      (value == null || value.isEmpty) ? l10n.password_required : null;

  static String? newPassword(String? value, AppLocalizations l10n) {
    final password = value ?? '';
    if (password.isEmpty) return l10n.password_required;
    if (!hasMinLength(password)) return l10n.password_length;
    if (!hasLettersAndDigits(password)) return l10n.password_letters_digits;
    return null;
  }

  static String? confirmPassword(String? value, String password, AppLocalizations l10n) {
    if (value == null || value.isEmpty) return l10n.confirm_password_required;
    if (value != password) return l10n.passwords_dont_match;
    return null;
  }

  static bool hasMinLength(String password) => password.length >= minPasswordLength;

  static bool hasLettersAndDigits(String password) => _letter.hasMatch(password) && _digit.hasMatch(password);
}

extension AuthFailureMessage on AuthFailure {
  String message(AppLocalizations l10n) => switch (this) {
        AuthFailure.invalidCredentials => l10n.auth_error_invalid_credentials,
        AuthFailure.emailNotConfirmed => l10n.auth_error_email_not_confirmed,
        AuthFailure.userAlreadyExists => l10n.auth_error_user_exists,
        AuthFailure.weakPassword => l10n.auth_error_weak_password,
        AuthFailure.samePassword => l10n.auth_error_same_password,
        AuthFailure.invalidEmail => l10n.auth_error_invalid_email,
        AuthFailure.signupDisabled => l10n.auth_error_signup_disabled,
        AuthFailure.rateLimited => l10n.auth_error_rate_limited,
        AuthFailure.network => l10n.auth_error_network,
        AuthFailure.linkInvalid => l10n.auth_error_link_invalid,
        AuthFailure.sessionExpired => l10n.auth_error_session_expired,
        AuthFailure.unknown => l10n.auth_error_unknown,
      };
}
