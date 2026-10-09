part of 'community_detail_bloc.dart';

sealed class CommunityDetailEvent {
  const CommunityDetailEvent();
}

final class CommunityDetailStarted extends CommunityDetailEvent {
  const CommunityDetailStarted();
}

/// Reloads the ranking and the member count from the server.
final class CommunityLeaderboardRefreshed extends CommunityDetailEvent {
  const CommunityLeaderboardRefreshed();
}

/// A user action; only one runs at a time.
sealed class _CommunityAction extends CommunityDetailEvent {
  const _CommunityAction();
}

/// Joins without taking part in the ranking.
final class CommunityJoinRequested extends _CommunityAction {
  const CommunityJoinRequested();
}

/// Creates a habit from the template and ranks with it; joins first if needed.
final class RankedHabitRequested extends _CommunityAction {
  final String title;
  final String description;

  const RankedHabitRequested({required this.title, required this.description});
}

final class CommunityLeaveRequested extends _CommunityAction {
  const CommunityLeaveRequested();
}

final class _MembershipChanged extends CommunityDetailEvent {
  final CommunityMembership? membership;

  const _MembershipChanged(this.membership);
}
