import 'dart:async';

import 'package:go_habit/core/app_connect/src/app_connect.dart';
import 'package:go_habit/core/sync/sync_service.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/communities/data/community_remote_data_source.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/communities/domain/models/habit_template.dart';
import 'package:go_habit/feature/communities/domain/repositories/community_repository.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/feature/habits/domain/repositories/habit_repository.dart';

const reading = HabitTemplate(
  id: 'reading',
  categoryId: 'education',
  title: {'ru': 'Чтение', 'en': 'Reading'},
  description: {'ru': 'Читать каждый день.', 'en': 'Read every day.'},
  icon: '📚',
  targetValue: 20,
  targetUnit: TargetUnit.pages,
  sortOrder: 10,
);

const walking = HabitTemplate(
  id: 'walking',
  categoryId: 'health',
  title: {'ru': 'Прогулка', 'en': 'Walking'},
  description: {'ru': 'Больше шагов.', 'en': 'More steps.'},
  icon: '🚶',
  targetValue: 8000,
  targetUnit: TargetUnit.steps,
  sortOrder: 20,
);

const noSugar = HabitTemplate(
  id: 'no-sugar',
  categoryId: 'health',
  title: {'ru': 'Без сладкого', 'en': 'No sugar'},
  description: {'ru': 'День без сладостей.', 'en': 'A day without sweets.'},
  icon: '🍏',
  sortOrder: 30,
);

const retired = HabitTemplate(
  id: 'retired',
  categoryId: 'art',
  title: {'ru': 'Архив', 'en': 'Archived'},
  description: {'ru': 'Старое.', 'en': 'Old.'},
  icon: '🗄️',
  sortOrder: 40,
  isActive: false,
);

/// Recommends a weekly target, so habits created from it start with that schedule.
final strength = HabitTemplate(
  id: 'strength-training',
  categoryId: 'health',
  title: const {'ru': 'Силовая тренировка', 'en': 'Strength training'},
  description: const {'ru': 'Тренировка с весом или собственным телом.', 'en': 'Weights or bodyweight training.'},
  icon: '🏋️',
  targetValue: 45,
  targetUnit: TargetUnit.minutes,
  sortOrder: 35,
  recommendedSchedule: HabitSchedule.weeklyTarget(3),
);

final today = CalendarDay(2026, 10, 9);

/// Server for a single signed-in user, with the same join semantics as
/// `public.join_community` (idempotent; a null habit keeps the ranked habit).
class FakeCommunityRemote implements CommunityRemoteDataSource {
  List<HabitTemplate> templates = [reading, walking, noSugar, retired];
  final memberships = <String, CommunityMembership>{};

  /// Members other than the signed-in user, by template id.
  final otherMembers = <String, int>{};

  /// Habit ids the server already has (the composite foreign key).
  final serverHabitIds = <String>{};
  List<LeaderboardEntry> leaderboardRows = [];
  final log = <String>[];

  /// Thrown by every call while set.
  CommunityFailure? failure;

  @override
  Future<List<HabitTemplate>> fetchTemplates() async => _call('templates', () => templates);

  @override
  Future<Map<String, int>> fetchMemberCounts() async => _call('counts', () {
        final counts = Map.of(otherMembers);
        for (final id in memberships.keys) {
          counts[id] = (counts[id] ?? 0) + 1;
        }
        return counts;
      });

  @override
  Future<List<CommunityMembership>> fetchMemberships() async => _call('memberships', () => memberships.values.toList());

  @override
  Future<CommunityMembership> join(
          {required String templateId, required CalendarDay joinedOn, String? habitId}) async =>
      _call('join:$templateId:$habitId', () {
        if (habitId != null && !serverHabitIds.contains(habitId)) {
          throw const CommunityException(CommunityFailure.habitNotSynced);
        }
        final existing = memberships[templateId];
        return memberships[templateId] = CommunityMembership(
          templateId: templateId,
          joinedOn: existing?.joinedOn ?? joinedOn,
          habitId: habitId ?? existing?.habitId,
        );
      });

  @override
  Future<void> leave(String templateId) async => _call('leave:$templateId', () => memberships.remove(templateId));

  @override
  Future<List<LeaderboardEntry>> fetchLeaderboard({required String templateId, required CalendarDay today}) async =>
      _call('leaderboard:$templateId', () => leaderboardRows);

  T _call<T>(String name, T Function() body) {
    log.add(name);
    if (failure case final failure?) throw CommunityException(failure);
    return body();
  }
}

class FakeConnect implements IAppConnect {
  // IAppConnect is @immutable, so the switch lives in a final holder.
  final _online = [true];

  bool get online => _online.first;
  set online(bool value) => _online[0] = value;

  @override
  Future<bool> hasConnect() async => online;

  @override
  Stream<bool> get onConnectChanged => const Stream.empty();
}

class FakeHabitRepository implements HabitRepository {
  final habits = <Habit>[];
  final log = <String>[];
  final _changes = StreamController<List<Habit>>.broadcast();

  @override
  Future<void> addHabit(Habit habit) async {
    log.add('add:${habit.title}');
    habits.add(habit);
    _changes.add(List.of(habits));
  }

  @override
  Future<void> deleteHabit(String id) async {
    log.add('delete:$id');
    habits.removeWhere((habit) => habit.id == id);
    _changes.add(List.of(habits));
  }

  @override
  Future<List<Habit>> getHabits() async => List.of(habits);

  @override
  Future<void> updateHabit(Habit habit) async => log.add('update:${habit.id}');

  @override
  Stream<List<Habit>> watchHabits() => _changes.stream;

  Future<void> dispose() => _changes.close();
}

/// Records sync requests; a successful sync uploads every local habit.
class FakeSession implements SessionDataManager {
  final List<String> log;
  final FakeHabitRepository? habits;
  final FakeCommunityRemote? remote;
  bool syncSucceeds = true;
  int pending = 0;

  FakeSession(this.log, {this.habits, this.remote});

  @override
  Future<bool> syncNow() async {
    log.add('sync');
    if (!syncSucceeds) return false;
    remote?.serverHabitIds.addAll(habits?.habits.map((h) => h.id) ?? const []);
    return true;
  }

  @override
  Future<int> pendingChangesCount() async => pending;

  @override
  Future<void> clearLocalData() async {}
}

/// In-memory [CommunityRepository] for bloc and widget tests.
class FakeCommunityRepository implements CommunityRepository {
  CommunityCatalog catalog;
  final memberships = <String, CommunityMembership>{};
  final _memberships = StreamController<Map<String, CommunityMembership>>.broadcast();
  final synced = StreamController<void>.broadcast();
  final log = <String>[];
  CommunityLeaderboard leaderboardResult = const CommunityLeaderboard(entries: [], rankedCount: 0);
  int? members = 3;
  bool unsynced = false;

  /// The schedule of the last habit created for a ranking.
  HabitSchedule? lastRankedSchedule;

  /// Thrown by the next calls of the named operations.
  final failures = <String, CommunityFailure>{};

  /// Operations wait for this completer, if set.
  Completer<void>? gate;

  FakeCommunityRepository({CommunityCatalog? catalog})
      : catalog = catalog ??
            CommunityCatalog(
              templates: [reading, walking, strength, noSugar, retired],
              memberships: const {},
              memberCounts: const {'reading': 3},
            );

  Future<void> _call(String name) async {
    log.add(name);
    await gate?.future;
    final failure = failures[name.split(':').first];
    if (failure != null) throw CommunityException(failure);
  }

  void _publish() => _memberships.add(Map.of(memberships));

  @override
  Future<CommunityCatalog> loadCatalog() async {
    await _call('catalog');
    return catalog.copyWith(memberships: Map.of(memberships));
  }

  @override
  Future<HabitTemplate?> getTemplate(String templateId) async {
    await _call('template');
    return catalog.templates.where((t) => t.id == templateId).firstOrNull;
  }

  @override
  Stream<Map<String, CommunityMembership>> watchMemberships() => _memberships.stream;

  @override
  Future<CommunityMembership> join(String templateId) async {
    await _call('join:$templateId');
    final membership = memberships[templateId] ??= CommunityMembership(templateId: templateId, joinedOn: today);
    _publish();
    return membership;
  }

  @override
  Future<CommunityMembership> joinWithRankedHabit(
    HabitTemplate template, {
    required String title,
    required String description,
    HabitSchedule schedule = HabitSchedule.daily,
  }) async {
    await _call('ranked:$title');
    lastRankedSchedule = schedule;
    final membership = CommunityMembership(
      templateId: template.id,
      joinedOn: memberships[template.id]?.joinedOn ?? today,
      habitId: 'ranked-habit',
    );
    memberships[template.id] = membership;
    _publish();
    return membership;
  }

  @override
  Future<void> leave(String templateId) async {
    await _call('leave:$templateId');
    memberships.remove(templateId);
    _publish();
  }

  @override
  Future<CommunityLeaderboard> leaderboard(String templateId, {required CalendarDay today}) async {
    await _call('leaderboard:$templateId');
    return leaderboardResult;
  }

  @override
  Future<int?> memberCount(String templateId) async => members;

  @override
  Future<bool> hasUnsyncedChanges() async => unsynced;

  @override
  Stream<void> get serverDataChanged => synced.stream;

  Future<void> dispose() async {
    await _memberships.close();
    await synced.close();
  }
}
