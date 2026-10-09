import 'package:go_habit/feature/social/domain/friend_action.dart';
import 'package:go_habit/feature/social/domain/models/social.dart';
import 'package:go_habit/feature/social/domain/nickname_rules.dart';
import 'package:go_habit/l10n/app_localizations.dart';

extension SocialFailureText on SocialFailure {
  String message(AppLocalizations l10n) => switch (this) {
        SocialFailure.offline => l10n.social_error_offline,
        SocialFailure.network => l10n.social_error_network,
        SocialFailure.nicknameTaken => l10n.social_nickname_taken,
        SocialFailure.nicknameInvalid => l10n.social_error_invalid_profile,
        SocialFailure.notFound => l10n.social_error_not_found,
        SocialFailure.blockedByMe => l10n.social_error_blocked_by_me,
        SocialFailure.notAllowed => l10n.social_error_not_allowed,
        SocialFailure.unauthorized => l10n.social_error_unauthorized,
        SocialFailure.unknown => l10n.social_error_unknown,
      };
}

extension NicknameErrorText on NicknameError {
  String message(AppLocalizations l10n) => switch (this) {
        NicknameError.empty => l10n.social_nickname_required,
        NicknameError.tooShort => l10n.social_nickname_too_short(NicknameRules.minLength),
        NicknameError.tooLong => l10n.social_nickname_too_long(NicknameRules.maxLength),
        NicknameError.mustStartWithLetter => l10n.social_nickname_start_letter,
        NicknameError.invalidCharacters => l10n.social_nickname_characters,
        NicknameError.reserved => l10n.social_nickname_reserved,
      };
}

extension ProfileVisibilityText on ProfileVisibility {
  String label(AppLocalizations l10n) => switch (this) {
        ProfileVisibility.everyone => l10n.social_visibility_everyone,
        ProfileVisibility.friends => l10n.social_visibility_friends,
        ProfileVisibility.nobody => l10n.social_visibility_nobody,
      };
}

extension SocialNoticeText on SocialNotice {
  /// Feedback after an action; null when no message is needed.
  String? message(AppLocalizations l10n) {
    final failure = this.failure;
    if (failure != null) return failure.message(l10n);
    return switch ((action, relationship)) {
      (FriendAction.send, Relationship.friends) => l10n.social_now_friends,
      (FriendAction.send, _) => l10n.social_request_sent,
      (FriendAction.accept, _) => l10n.social_now_friends,
      (FriendAction.reject, _) => l10n.social_request_rejected,
      (FriendAction.cancel, Relationship.friends) => l10n.social_already_accepted,
      (FriendAction.cancel, _) => l10n.social_request_cancelled,
      (FriendAction.remove, _) => l10n.social_friend_removed,
      (FriendAction.block, _) => l10n.social_user_blocked,
      (FriendAction.unblock, _) => l10n.social_user_unblocked,
      _ => null,
    };
  }
}

/// A user's handle for display: "@nickname", or a neutral label without one.
String displayHandle(String? nickname, AppLocalizations l10n) =>
    nickname == null ? l10n.community_member_fallback : '@$nickname';
