import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:go_habit/core/database/drift_database.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/communities/domain/models/habit_template.dart';

/// The signed-in user's participation in the community of [templateId].
@immutable
class CommunityMembership {
  final String templateId;

  /// The ranked habit, created from the template; null for a member without ranking.
  final String? habitId;

  /// Days before this one are not scored.
  final CalendarDay joinedOn;

  const CommunityMembership({required this.templateId, required this.joinedOn, this.habitId});

  bool get isRanked => habitId != null;

  factory CommunityMembership.fromJson(Map<String, dynamic> json) => CommunityMembership(
        templateId: json['template_id'] as String,
        habitId: json['habit_id'] as String?,
        joinedOn: CalendarDay.parse(json['joined_on'] as String),
      );

  factory CommunityMembership.fromDriftModel(CommunityMembershipEntry entry) => CommunityMembership(
        templateId: entry.templateId,
        habitId: entry.habitId,
        joinedOn: CalendarDay.parse(entry.joinedOn),
      );

  CommunityMembershipsCompanion toCompanion() => CommunityMembershipsCompanion.insert(
        templateId: templateId,
        habitId: Value(habitId),
        joinedOn: joinedOn.toIsoString(),
      );

  @override
  bool operator ==(Object other) =>
      other is CommunityMembership &&
      other.templateId == templateId &&
      other.habitId == habitId &&
      other.joinedOn == joinedOn;

  @override
  int get hashCode => Object.hash(templateId, habitId, joinedOn);
}

/// Catalog, participant counts and the user's memberships.
@immutable
class CommunityCatalog {
  final List<HabitTemplate> templates;

  /// Real participant counts by template id; null when they could not be loaded
  /// (offline), so no number is shown instead of a stale one.
  final Map<String, int>? memberCounts;
  final Map<String, CommunityMembership> memberships;

  /// The data comes from the device cache because the server was unreachable.
  final bool isOffline;

  const CommunityCatalog({
    required this.templates,
    required this.memberships,
    this.memberCounts,
    this.isOffline = false,
  });

  CommunityCatalog copyWith({Map<String, CommunityMembership>? memberships, Map<String, int>? memberCounts}) =>
      CommunityCatalog(
        templates: templates,
        memberships: memberships ?? this.memberships,
        memberCounts: memberCounts ?? this.memberCounts,
        isOffline: isOffline,
      );
}

/// One row of a weekly ranking, computed by the server.
@immutable
class LeaderboardEntry {
  /// Null for the caller's own row while they are not ranked yet.
  final int? rank;

  /// Public display name; null means the member has none, show a neutral label.
  final String? displayName;
  final bool isMe;
  final int completedDays;
  final int eligibleDays;

  /// 0–100 with full precision; null when not ranked.
  final double? consistency;

  /// Members ranked this week (the same on every row).
  final int rankedCount;

  const LeaderboardEntry({
    required this.isMe,
    required this.completedDays,
    required this.eligibleDays,
    this.rank,
    this.displayName,
    this.consistency,
    this.rankedCount = 0,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
        rank: json['rank'] as int?,
        displayName: json['display_name'] as String?,
        isMe: json['is_me'] as bool? ?? false,
        completedDays: json['completed_days'] as int? ?? 0,
        eligibleDays: json['eligible_days'] as int? ?? 0,
        consistency: (json['consistency'] as num?)?.toDouble(),
        rankedCount: json['ranked_count'] as int? ?? 0,
      );

  /// Rounded for display; ranking uses the full value.
  int? get roundedPercent => consistency?.round();
}

/// The current week's ranking of a community.
@immutable
class CommunityLeaderboard {
  /// Ranked rows in rank order, possibly including the caller's own row below the top.
  final List<LeaderboardEntry> entries;

  /// The caller's own row (ranked or not); null if they are not a member.
  final LeaderboardEntry? me;

  /// How many members are ranked this week.
  final int rankedCount;

  const CommunityLeaderboard({required this.entries, required this.rankedCount, this.me});

  factory CommunityLeaderboard.fromRows(List<LeaderboardEntry> rows) {
    final ranked = rows.where((row) => row.rank != null).toList()..sort((a, b) => a.rank!.compareTo(b.rank!));
    return CommunityLeaderboard(
      entries: ranked,
      me: rows.where((row) => row.isMe).firstOrNull,
      rankedCount: rows.firstOrNull?.rankedCount ?? 0,
    );
  }
}

/// Why a community operation failed.
enum CommunityFailure {
  /// Joining, leaving and rankings need a connection.
  offline,
  network,

  /// The new ranked habit did not reach the server; it was removed again.
  habitNotSynced,

  /// The community was retired.
  notAllowed,
  unauthorized,
  unknown,
}

final class CommunityException implements Exception {
  final CommunityFailure failure;

  const CommunityException(this.failure);

  @override
  String toString() => 'CommunityException($failure)';
}
