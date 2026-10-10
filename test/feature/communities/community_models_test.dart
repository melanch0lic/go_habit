import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/database/dao/community_dao.dart';
import 'package:go_habit/core/database/drift_database.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/communities/data/community_remote_data_source.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/communities/domain/models/habit_template.dart';
import 'package:go_habit/feature/communities/view/community_texts.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/l10n/app_localizations_en.dart';
import 'package:go_habit/l10n/app_localizations_ru.dart';

void main() {
  final row = <String, dynamic>{
    'id': 'reading',
    'category_id': 'education',
    'title': {'ru': 'Чтение', 'en': 'Reading'},
    'description': {'ru': 'Читать каждый день.', 'en': 'Read every day.'},
    'icon': '📚',
    'target_value': 20,
    'target_unit': 'pages',
    'sort_order': 10,
    'is_active': true,
  };

  group('HabitTemplate', () {
    test('parses a server row', () {
      final template = HabitTemplate.fromJson(row);
      expect(template.id, 'reading');
      expect(template.titleFor('en'), 'Reading');
      expect(template.titleFor('ru'), 'Чтение');
      expect(template.targetUnit, TargetUnit.pages);
      expect(template.hasTarget, isTrue);
    });

    test('falls back to Russian for other languages', () {
      expect(HabitTemplate.fromJson(row).titleFor('de'), 'Чтение');
    });

    test('ignores an unknown unit instead of failing', () {
      final template = HabitTemplate.fromJson({...row, 'target_unit': 'liters'});
      expect(template.targetUnit, isNull);
      expect(template.hasTarget, isFalse);
    });

    test('searches titles and descriptions in every language', () {
      final template = HabitTemplate.fromJson(row);
      expect(template.matches(''), isTrue);
      expect(template.matches('read'), isTrue);
      expect(template.matches('чтен'), isTrue);
      expect(template.matches('каждый'), isTrue);
      expect(template.matches('run'), isFalse);
    });

    test('formats the target in both languages', () {
      final template = HabitTemplate.fromJson(row);
      expect(template.targetText(AppLocalizationsRu()), '20 страниц');
      expect(template.targetText(AppLocalizationsEn()), '20 pages');
      expect(template.targetText(AppLocalizationsRu(), value: 1), '1 страница');
    });

    test('reads the recommended schedule as structured data', () {
      expect(HabitTemplate.fromJson(row).recommendedSchedule, HabitSchedule.daily, reason: 'older rows: daily');
      expect(
        HabitTemplate.fromJson({...row, 'schedule': 'weekly_target', 'weekly_target': 3}).recommendedSchedule,
        HabitSchedule.weeklyTarget(3),
      );
      expect(
        HabitTemplate.fromJson({...row, 'schedule': 'weekdays', 'schedule_days': 31}).recommendedSchedule,
        HabitSchedule.weekdays({1, 2, 3, 4, 5}),
      );
      expect(HabitTemplate.columns, allOf(contains('schedule'), contains('weekly_target'), contains('schedule_days')));
    });

    test('survives the device cache unchanged', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dao = CommunityDao(db);
      final template = HabitTemplate.fromJson({...row, 'schedule': 'weekdays', 'schedule_days': 21});
      await dao.replaceTemplates([template.toCompanion()]);

      final cached = HabitTemplate.fromDriftModel((await dao.getTemplates()).single);
      expect(cached.title, template.title);
      expect(cached.description, template.description);
      expect(cached.targetValue, 20);
      expect(cached.targetUnit, TargetUnit.pages);
      expect(cached.recommendedSchedule, HabitSchedule.weekdays({1, 3, 5}));

      // Refreshing the cache replaces entries instead of duplicating them.
      await dao.replaceTemplates([template.toCompanion()]);
      expect(await dao.getTemplates(), hasLength(1));
      await db.close();
    });
  });

  group('leaderboard rows', () {
    test('ranked rows are sorted; the caller and the ranked count are kept', () {
      final leaderboard = CommunityLeaderboard.fromRows([
        LeaderboardEntry.fromJson(const {
          'rank': 2,
          'display_name': null,
          'is_me': true,
          'completed_days': 3,
          'eligible_days': 4,
          'consistency': 75,
          'ranked_count': 3,
        }),
        LeaderboardEntry.fromJson(const {
          'rank': 1,
          'display_name': 'Alice',
          'is_me': false,
          'completed_days': 5,
          'eligible_days': 5,
          'consistency': 100,
          'ranked_count': 3,
        }),
      ]);
      expect(leaderboard.entries.map((e) => e.rank), [1, 2]);
      expect(leaderboard.me!.rank, 2);
      expect(leaderboard.rankedCount, 3);
    });

    test('percentages are rounded only for display', () {
      final entry = LeaderboardEntry.fromJson(const {
        'rank': 1,
        'is_me': false,
        'completed_days': 5,
        'eligible_days': 7,
        'consistency': 71.428571,
        'ranked_count': 1,
      });
      expect(entry.consistency, closeTo(71.4286, 0.0001));
      expect(entry.displayPercent, 71.4, reason: 'one decimal for display');
    });

    test('community rows carry actions, successful weeks and the reason for an unranked row', () {
      final ranked = LeaderboardEntry.fromJson(const {
        'rank': 1,
        'is_me': false,
        'completed_actions': 2,
        'expected_actions': 3,
        'consistency': 66.666666,
        'ranked_count': 4,
        'success_weeks': 3,
        'status': 'scored',
      });
      expect((ranked.completed, ranked.expected, ranked.successWeeks), (2, 3, 3));
      expect(ranked.displayPercent, 66.7);

      final me = LeaderboardEntry.fromJson(const {'rank': null, 'is_me': true, 'status': 'joined_recently'});
      expect((me.status, me.consistency, me.expected), (LeaderboardStatus.joinedRecently, null, 0));
      expect(LeaderboardEntry.fromJson(const {'is_me': true, 'status': 'paused'}).status, LeaderboardStatus.paused);
      expect(LeaderboardEntry.fromJson(const {'is_me': true, 'status': 'no_scheduled_actions'}).status,
          LeaderboardStatus.noScheduledActions);
      expect(LeaderboardEntry.fromJson(const {'is_me': true, 'status': 'no_habit'}).status, LeaderboardStatus.noHabit);
    });

    test('display rounding: one decimal, full precision kept', () {
      LeaderboardEntry entry(double value) =>
          LeaderboardEntry(isMe: false, completed: 0, expected: 1, consistency: value);
      expect(entry(6 * 100 / 7).displayPercent, 85.7);
      expect(entry(4 * 100 / 7).displayPercent, 57.1);
      expect(entry(80).displayPercent, 80);
      expect(entry(99.96).displayPercent, 100);
      expect(entry(6 * 100 / 7).consistency, closeTo(85.714285, 0.000001));
      expect(const LeaderboardEntry(isMe: true, completed: 0, expected: 0).displayPercent, isNull,
          reason: 'no score is invented');
    });

    test('an unranked caller row is not listed among the ranks', () {
      final leaderboard = CommunityLeaderboard.fromRows([
        LeaderboardEntry.fromJson(const {'rank': null, 'is_me': true, 'completed_days': 0, 'eligible_days': 0}),
      ]);
      expect(leaderboard.entries, isEmpty);
      expect(leaderboard.me!.rank, isNull);
    });
  });

  test('membership parses the server row', () {
    final membership = CommunityMembership.fromJson(const {
      'template_id': 'reading',
      'habit_id': 'h1',
      'joined_on': '2026-10-09',
    });
    expect(membership.joinedOn, CalendarDay(2026, 10, 9));
    expect(membership.habitId, 'h1');
    expect(membership.isRanked, isTrue);
    expect(CommunityMembership.fromJson(const {'template_id': 'reading', 'joined_on': '2026-10-09'}).isRanked, isFalse);
  });

  test('server errors map to user-facing failures', () {
    expect(SupabaseCommunityDataSource.mapPostgrestFailure('23503'), CommunityFailure.habitNotSynced);
    expect(SupabaseCommunityDataSource.mapPostgrestFailure('23514'), CommunityFailure.notAllowed);
    expect(SupabaseCommunityDataSource.mapPostgrestFailure('23505'), CommunityFailure.notAllowed);
    expect(SupabaseCommunityDataSource.mapPostgrestFailure('42501'), CommunityFailure.unauthorized);
    expect(SupabaseCommunityDataSource.mapPostgrestFailure('PGRST301'), CommunityFailure.unauthorized);
    expect(SupabaseCommunityDataSource.mapPostgrestFailure('22023'), CommunityFailure.unknown);
    expect(SupabaseCommunityDataSource.mapPostgrestFailure(null), CommunityFailure.unknown);
  });

  test('every failure has a message in both languages', () {
    for (final l10n in [AppLocalizationsRu(), AppLocalizationsEn()]) {
      final messages = CommunityFailure.values.map((f) => f.message(l10n)).toSet();
      expect(messages, hasLength(CommunityFailure.values.length));
    }
  });
}
