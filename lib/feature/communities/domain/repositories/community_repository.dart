import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/communities/domain/models/habit_template.dart';

/// Catalog, membership and rankings. Failures are thrown as [CommunityException].
///
/// Browsing works offline from the device cache. Joining, leaving and rankings need
/// a connection: the server decides membership and computes scores. Only a habit
/// created from the community's template can take part in its ranking.
abstract interface class CommunityRepository {
  /// Loads the catalog, participant counts and memberships, refreshing the cache.
  /// Falls back to the cache when the server is unreachable.
  Future<CommunityCatalog> loadCatalog();

  /// A template from the cache, or from the server if it is not cached yet.
  Future<HabitTemplate?> getTemplate(String templateId);

  /// The user's memberships by template id, from the cache.
  Stream<Map<String, CommunityMembership>> watchMemberships();

  /// Joins without taking part in the ranking (idempotent). Habits are not touched.
  Future<CommunityMembership> join(String templateId);

  /// Creates a personal habit from [template] with the user's [title] and
  /// [description] and makes it the ranked habit, joining first if needed. If the
  /// server does not accept it, the new habit is removed again, so a retry never
  /// leaves a duplicate.
  Future<CommunityMembership> joinWithRankedHabit(
    HabitTemplate template, {
    required String title,
    required String description,
  });

  /// Leaves the community. The ranked habit and its history are kept.
  Future<void> leave(String templateId);

  /// The current week's ranking, computed by the server for the user's [today].
  Future<CommunityLeaderboard> leaderboard(String templateId, {required CalendarDay today});

  /// The real number of members, or null if it cannot be loaded right now.
  Future<int?> memberCount(String templateId);

  /// Whether local habit changes still wait for upload (the ranking does not show them yet).
  Future<bool> hasUnsyncedChanges();

  /// Emits after a synchronization reached the server, so rankings can be reloaded.
  Stream<void> get serverDataChanged;
}
