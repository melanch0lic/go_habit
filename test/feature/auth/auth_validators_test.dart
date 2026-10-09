import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/feature/auth/view/auth_validators.dart';
import 'package:go_habit/l10n/app_localizations_ru.dart';

void main() {
  final l10n = AppLocalizationsRu();

  group('email', () {
    test('requires a value', () {
      expect(AuthValidators.email(null, l10n), l10n.email_required);
      expect(AuthValidators.email('   ', l10n), l10n.email_required);
    });

    test('accepts real-world addresses', () {
      for (final email in [
        'user@example.com',
        'first.last+habits@sub.example.co.uk',
        'name@company.photography',
        '  padded@example.com ', // autofill often adds spaces
      ]) {
        expect(AuthValidators.email(email, l10n), isNull, reason: email);
      }
    });

    test('rejects malformed addresses', () {
      for (final email in ['user', 'user@', '@example.com', 'user@example', 'us er@example.com', 'a@b@c.com']) {
        expect(AuthValidators.email(email, l10n), l10n.email_invalid, reason: email);
      }
    });

    test('normalizes surrounding spaces', () {
      expect(AuthValidators.normalizeEmail('  user@example.com\n'), 'user@example.com');
    });
  });

  group('passwords', () {
    test('sign-in only requires a value, so older passwords still work', () {
      expect(AuthValidators.existingPassword('', l10n), l10n.password_required);
      expect(AuthValidators.existingPassword('abc', l10n), isNull);
    });

    test('a new password follows the project rules', () {
      expect(AuthValidators.newPassword('', l10n), l10n.password_required);
      expect(AuthValidators.newPassword('a1b2c', l10n), l10n.password_length);
      expect(AuthValidators.newPassword('abcdefgh', l10n), l10n.password_letters_digits);
      expect(AuthValidators.newPassword('12345678', l10n), l10n.password_letters_digits);
      expect(AuthValidators.newPassword('habit1', l10n), isNull);
      expect(AuthValidators.newPassword('привычка1', l10n), isNull);
    });

    test('confirmation must match', () {
      expect(AuthValidators.confirmPassword('', 'habit1', l10n), l10n.confirm_password_required);
      expect(AuthValidators.confirmPassword('habit2', 'habit1', l10n), l10n.passwords_dont_match);
      expect(AuthValidators.confirmPassword('habit1', 'habit1', l10n), isNull);
    });
  });
}
