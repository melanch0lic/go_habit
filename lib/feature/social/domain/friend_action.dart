import 'package:go_habit/feature/social/domain/models/social.dart';
import 'package:go_habit/feature/social/domain/repositories/social_repository.dart';

/// A relationship change the user can trigger.
enum FriendAction {
  send,
  accept,
  reject,
  cancel,
  remove,
  block,
  unblock;

  Future<Relationship> run(SocialRepository repository, String publicId) => switch (this) {
        FriendAction.send => repository.sendRequest(publicId),
        FriendAction.accept => repository.respondToRequest(publicId, accept: true),
        FriendAction.reject => repository.respondToRequest(publicId, accept: false),
        FriendAction.cancel => repository.cancelRequest(publicId),
        FriendAction.remove => repository.removeFriend(publicId),
        FriendAction.block => repository.block(publicId),
        FriendAction.unblock => repository.unblock(publicId),
      };
}

/// The result of an action or an error, shown once.
final class SocialNotice {
  final FriendAction? action;

  /// The relationship the server reported after [action].
  final Relationship? relationship;
  final SocialFailure? failure;

  const SocialNotice.done(FriendAction this.action, Relationship this.relationship) : failure = null;

  const SocialNotice.failed(SocialFailure this.failure, {this.action}) : relationship = null;
}
