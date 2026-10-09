part of 'community_detail_bloc.dart';

enum LoadStatus { initial, loading, ready, failure }

enum CommunityOutcome { joined, joinedRanked, rankedHabitCreated, left, failed }

/// The result of an action, shown once.
@immutable
final class CommunityNotice {
  final CommunityOutcome outcome;
  final CommunityFailure? failure;

  const CommunityNotice({required this.outcome, this.failure});
}

@immutable
final class CommunityDetailState {
  final String templateId;
  final LoadStatus templateStatus;
  final HabitTemplate? template;
  final CommunityFailure? templateFailure;

  /// From the device cache, which mirrors the server after every join or leave.
  final CommunityMembership? membership;

  final LoadStatus leaderboardStatus;

  /// The last loaded ranking; kept while reloading.
  final CommunityLeaderboard? leaderboard;
  final CommunityFailure? leaderboardFailure;

  /// Real number of members; null while unknown.
  final int? memberCount;

  /// Local changes wait for upload, so the ranking may not include them yet.
  final bool hasUnsyncedChanges;
  final bool isBusy;
  final CommunityNotice? notice;

  const CommunityDetailState({
    required this.templateId,
    this.templateStatus = LoadStatus.initial,
    this.template,
    this.templateFailure,
    this.membership,
    this.leaderboardStatus = LoadStatus.initial,
    this.leaderboard,
    this.leaderboardFailure,
    this.memberCount,
    this.hasUnsyncedChanges = false,
    this.isBusy = false,
    this.notice,
  });

  bool get isMember => membership != null;

  CommunityDetailState copyWith({
    LoadStatus? templateStatus,
    HabitTemplate? template,
    CommunityFailure? Function()? templateFailure,
    CommunityMembership? Function()? membership,
    LoadStatus? leaderboardStatus,
    CommunityLeaderboard? Function()? leaderboard,
    CommunityFailure? Function()? leaderboardFailure,
    int? Function()? memberCount,
    bool? hasUnsyncedChanges,
    bool? isBusy,
    CommunityNotice? Function()? notice,
  }) =>
      CommunityDetailState(
        templateId: templateId,
        templateStatus: templateStatus ?? this.templateStatus,
        template: template ?? this.template,
        templateFailure: templateFailure != null ? templateFailure() : this.templateFailure,
        membership: membership != null ? membership() : this.membership,
        leaderboardStatus: leaderboardStatus ?? this.leaderboardStatus,
        leaderboard: leaderboard != null ? leaderboard() : this.leaderboard,
        leaderboardFailure: leaderboardFailure != null ? leaderboardFailure() : this.leaderboardFailure,
        memberCount: memberCount != null ? memberCount() : this.memberCount,
        hasUnsyncedChanges: hasUnsyncedChanges ?? this.hasUnsyncedChanges,
        isBusy: isBusy ?? this.isBusy,
        // A notice is delivered once: any later state clears it unless replaced.
        notice: notice?.call(),
      );
}
