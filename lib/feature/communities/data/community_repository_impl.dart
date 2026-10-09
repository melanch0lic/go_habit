import 'dart:async';

import 'package:go_habit/core/app_connect/src/app_connect.dart';
import 'package:go_habit/core/database/dao/community_dao.dart';
import 'package:go_habit/core/sync/sync_service.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/communities/data/community_remote_data_source.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/communities/domain/models/habit_template.dart';
import 'package:go_habit/feature/communities/domain/repositories/community_repository.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/repositories/habit_repository.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  final CommunityRemoteDataSource _remote;
  final CommunityDao _dao;
  final IAppConnect _appConnect;
  final HabitRepository _habits;
  final SessionDataManager _session;
  final Stream<void> _synced;
  final CalendarDay Function() _today;

  CommunityRepositoryImpl({
    required CommunityRemoteDataSource remote,
    required CommunityDao dao,
    required IAppConnect appConnect,
    required HabitRepository habits,
    required SessionDataManager session,
    required Stream<void> synced,
    CalendarDay Function()? today,
  })  : _remote = remote,
        _dao = dao,
        _appConnect = appConnect,
        _habits = habits,
        _session = session,
        _synced = synced,
        _today = today ?? CalendarDay.today;

  @override
  Future<CommunityCatalog> loadCatalog() async {
    final List<Object> results;
    try {
      results = await Future.wait<Object>([
        _remote.fetchTemplates(),
        _remote.fetchMemberCounts(),
        _remote.fetchMemberships(),
      ]);
    } on CommunityException catch (e) {
      return _cachedCatalog(e.failure);
    }
    final templates = results[0] as List<HabitTemplate>;
    final counts = results[1] as Map<String, int>;
    final memberships = results[2] as List<CommunityMembership>;
    await _dao.replaceTemplates([for (final template in templates) template.toCompanion()]);
    await _dao.replaceMemberships([for (final membership in memberships) membership.toCompanion()]);
    return CommunityCatalog(
      templates: templates,
      memberCounts: counts,
      memberships: {for (final membership in memberships) membership.templateId: membership},
    );
  }

  /// A network failure falls back to the cache; anything else (e.g. an expired
  /// session), or an empty cache, is reported.
  Future<CommunityCatalog> _cachedCatalog(CommunityFailure failure) async {
    if (failure != CommunityFailure.network) throw CommunityException(failure);
    final templates = (await _dao.getTemplates()).map(HabitTemplate.fromDriftModel).toList();
    if (templates.isEmpty) throw const CommunityException(CommunityFailure.network);
    final memberships = (await _dao.getMemberships()).map(CommunityMembership.fromDriftModel);
    return CommunityCatalog(
      templates: templates,
      memberships: {for (final membership in memberships) membership.templateId: membership},
      isOffline: true,
    );
  }

  @override
  Future<HabitTemplate?> getTemplate(String templateId) async {
    final cached = (await _dao.getTemplates()).where((entry) => entry.id == templateId).firstOrNull;
    if (cached != null) return HabitTemplate.fromDriftModel(cached);
    final catalog = await loadCatalog();
    return catalog.templates.where((template) => template.id == templateId).firstOrNull;
  }

  @override
  Stream<Map<String, CommunityMembership>> watchMemberships() => _dao.watchMemberships().map(
        (rows) => {for (final row in rows) row.templateId: CommunityMembership.fromDriftModel(row)},
      );

  @override
  Future<CommunityMembership> join(String templateId) async {
    await _requireConnection();
    return _join(templateId);
  }

  @override
  Future<CommunityMembership> joinWithRankedHabit(
    HabitTemplate template, {
    required String title,
    required String description,
  }) async {
    // Checked before creating the habit, so an offline attempt leaves nothing behind.
    await _requireConnection();
    final habit = Habit(title: title, description: description, categoryId: template.categoryId, icon: template.icon);
    await _habits.addHabit(habit);
    try {
      // The server only accepts a habit it already has.
      await _session.syncNow();
      return await _join(template.id, habitId: habit.id);
    } on CommunityException {
      // Undo, so retrying does not create a second habit.
      await _habits.deleteHabit(habit.id);
      rethrow;
    }
  }

  Future<CommunityMembership> _join(String templateId, {String? habitId}) async {
    final membership = await _remote.join(templateId: templateId, habitId: habitId, joinedOn: _today());
    await _dao.saveMembership(membership.toCompanion());
    return membership;
  }

  @override
  Future<void> leave(String templateId) async {
    await _requireConnection();
    await _remote.leave(templateId);
    await _dao.deleteMembership(templateId);
  }

  @override
  Future<CommunityLeaderboard> leaderboard(String templateId, {required CalendarDay today}) async {
    await _requireConnection();
    return CommunityLeaderboard.fromRows(await _remote.fetchLeaderboard(templateId: templateId, today: today));
  }

  @override
  Future<int?> memberCount(String templateId) async {
    try {
      return (await _remote.fetchMemberCounts())[templateId] ?? 0;
    } on CommunityException {
      return null;
    }
  }

  @override
  Future<bool> hasUnsyncedChanges() async => await _session.pendingChangesCount() > 0;

  @override
  Stream<void> get serverDataChanged => _synced;

  Future<void> _requireConnection() async {
    if (!await _appConnect.hasConnect()) throw const CommunityException(CommunityFailure.offline);
  }
}
