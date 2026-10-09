import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/database/dao/community_dao.dart';
import 'package:go_habit/core/database/drift_database.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/communities/data/community_remote_data_source.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/communities/domain/models/habit_template.dart';
import 'package:go_habit/feature/communities/view/community_texts.dart';
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

    test('survives the device cache unchanged', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dao = CommunityDao(db);
      final template = HabitTemplate.fromJson(row);
      await dao.replaceTemplates([template.toCompanion()]);

      final cached = HabitTemplate.fromDriftModel((await dao.getTemplates()).single);
      expect(cached.title, template.title);
      expect(cached.description, template.description);
      expect(cached.targetValue, 20);
      expect(cached.targetUnit, TargetUnit.pages);
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
      expect(entry.roundedPercent, 71);
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
