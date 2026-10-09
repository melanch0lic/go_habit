/// Why a nickname is not acceptable. Mirrors the `profile_nickname_format` check in
/// the database, which has the final word.
enum NicknameError { empty, tooShort, tooLong, mustStartWithLetter, invalidCharacters, reserved }

abstract final class NicknameRules {
  static const minLength = 3;
  static const maxLength = 20;

  static const reserved = {'admin', 'administrator', 'moderator', 'support', 'system', 'gohabit', 'go_habit'};

  static final _allowed = RegExp(r'^[A-Za-z0-9_]+$');
  static final _letter = RegExp('^[A-Za-z]');

  static String normalize(String value) => value.trim();

  /// Null when [value] is a valid nickname.
  static NicknameError? validate(String value) {
    final nickname = normalize(value);
    if (nickname.isEmpty) return NicknameError.empty;
    if (!_allowed.hasMatch(nickname)) return NicknameError.invalidCharacters;
    if (!_letter.hasMatch(nickname)) return NicknameError.mustStartWithLetter;
    if (nickname.length < minLength) return NicknameError.tooShort;
    if (nickname.length > maxLength) return NicknameError.tooLong;
    if (reserved.contains(nickname.toLowerCase())) return NicknameError.reserved;
    return null;
  }

  /// Nicknames are unique regardless of case.
  static bool same(String a, String b) => normalize(a).toLowerCase() == normalize(b).toLowerCase();
}
