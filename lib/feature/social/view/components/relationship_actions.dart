import 'package:flutter/material.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/feature/social/domain/friend_action.dart';
import 'package:go_habit/feature/social/domain/models/social.dart';

/// The friend actions that fit [relationship], as compact buttons.
class RelationshipActions extends StatelessWidget {
  final Relationship relationship;
  final bool busy;
  final ValueChanged<FriendAction> onAction;

  /// Shows the full set for a profile screen (including removing a friend).
  final bool expanded;

  const RelationshipActions({
    required this.relationship,
    required this.onAction,
    this.busy = false,
    this.expanded = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final green = context.theme.commonColors.green100;

    if (busy) {
      return const SizedBox(
        height: 48,
        child: Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    Widget primary(String label, FriendAction action, {IconData? icon}) => FilledButton.icon(
          onPressed: () => onAction(action),
          style: FilledButton.styleFrom(backgroundColor: green, minimumSize: const Size(48, 40)),
          icon: Icon(icon ?? Icons.person_add_alt_1, size: 18),
          label: Text(label),
        );

    Widget secondary(String label, FriendAction action) => OutlinedButton(
          onPressed: () => onAction(action),
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 40)),
          child: Text(label),
        );

    final buttons = switch (relationship) {
      Relationship.self => const <Widget>[],
      Relationship.none => [primary(l10n.social_add_friend, FriendAction.send)],
      Relationship.outgoing => [secondary(l10n.social_cancel_request, FriendAction.cancel)],
      Relationship.incoming => [
          primary(l10n.social_accept, FriendAction.accept, icon: Icons.check),
          secondary(l10n.social_reject, FriendAction.reject),
        ],
      Relationship.friends => [
          if (expanded)
            secondary(l10n.social_remove_friend, FriendAction.remove)
          else
            Chip(avatar: Icon(Icons.check, size: 16, color: green), label: Text(l10n.social_friends_badge)),
        ],
      Relationship.blocked => [secondary(l10n.social_unblock, FriendAction.unblock)],
    };
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }
}
