import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/communities/domain/weekly_consistency.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';

void main() {
  // Monday 2026-10-05 .. Sunday 2026-10-11.
  final monday = CalendarDay(2026, 10, 5);
  final sunday = CalendarDay(2026, 10, 11);
  final longAgo = DateTime.utc(2000);

  List<CalendarDay> days(CalendarDay from, int count) => [for (var i = 0; i < count; i++) from.addDays(i)];

  group('week boundary', () {
    test('weeks start on Monday', () {
      for (final day in days(monday, 7)) {
        expect(WeeklyConsistency.weekStart(day), monday, reason: '$day');
      }
      expect(WeeklyConsistency.weekStart(sunday.addDays(1)), sunday.addDays(1));
    });

    test('a daylight-saving week still has seven days', () {
      for (final sundayOfChange in [CalendarDay(2026, 3, 29), CalendarDay(2026, 11, 1)]) {
        final start = WeeklyConsistency.weekStart(sundayOfChange);
        expect(sundayOfChange.differenceInDays(start), 6);
        final result = WeeklyConsistency.compute(
          today: sundayOfChange,
          joinedOn: start.addDays(-30),
          habitCreatedAt: longAgo,
          completedDays: days(start, 7),
        );
        expect(result, const WeeklyConsistency(completedDays: 7, eligibleDays: 7));
      }
    });
  });

  group('compute', () {
    test('5 of 7 scheduled days is 71.43%', () {
      final result = WeeklyConsistency.compute(
        today: sunday,
        joinedOn: monday.addDays(-10),
        habitCreatedAt: longAgo,
        completedDays: days(monday, 5),
      );
      expect(result, const WeeklyConsistency(completedDays: 5, eligibleDays: 7));
      expect(result.percentage!.toStringAsFixed(2), '71.43');
    });

    test('days of other weeks and future days do not count', () {
      final wednesday = monday.addDays(2);
      final result = WeeklyConsistency.compute(
        today: wednesday,
        joinedOn: monday.addDays(-10),
        habitCreatedAt: longAgo,
        completedDays: [monday.addDays(-1), monday, wednesday, wednesday.addDays(1)],
      );
      expect(result, const WeeklyConsistency(completedDays: 2, eligibleDays: 3));
    });

    test('days before joining are not eligible', () {
      final result = WeeklyConsistency.compute(
        today: sunday,
        joinedOn: monday.addDays(3),
        habitCreatedAt: longAgo,
        completedDays: days(monday, 7),
      );
      expect(result, const WeeklyConsistency(completedDays: 4, eligibleDays: 4));
    });

    test('days before the habit was created (UTC day, as on the server) are not eligible', () {
      final result = WeeklyConsistency.compute(
        today: sunday,
        joinedOn: monday.addDays(-10),
        habitCreatedAt: DateTime.utc(2026, 10, 9, 10),
        completedDays: days(monday, 7),
      );
      expect(result, const WeeklyConsistency(completedDays: 3, eligibleDays: 3));
    });

    test('duplicate records of a day count once', () {
      final result = WeeklyConsistency.compute(
        today: monday.addDays(1),
        joinedOn: monday,
        habitCreatedAt: longAgo,
        completedDays: [monday, monday, CalendarDay.parse('2026-10-05')],
      );
      expect(result, const WeeklyConsistency(completedDays: 1, eligibleDays: 2));
    });

    test('a join day after today (other time zone) leaves nothing to score', () {
      final result = WeeklyConsistency.compute(
        today: sunday,
        joinedOn: sunday.addDays(1),
        habitCreatedAt: longAgo,
        completedDays: [sunday],
      );
      expect(result.isScored, isFalse);
      expect(result.percentage, isNull);
    });

    test('a paused habit is not scored', () {
      final result = WeeklyConsistency.compute(
        today: sunday,
        joinedOn: monday,
        habitCreatedAt: longAgo,
        completedDays: days(monday, 7),
        habitActive: false,
      );
      expect(result, WeeklyConsistency.notScored);
    });
  });

  // The same cases as supabase/tests/database/04_schedules.test.sql, so the device and
  // the server rankings agree.
  group('schedules', () {
    final mwf = HabitSchedule.weekdays({DateTime.monday, DateTime.wednesday, DateTime.friday});
    WeeklyConsistency score(HabitSchedule schedule, List<CalendarDay> done, {CalendarDay? today}) =>
        WeeklyConsistency.compute(
          today: today ?? sunday,
          joinedOn: monday.addDays(-4),
          habitCreatedAt: longAgo,
          completedDays: done,
          schedule: schedule,
        );

    test('weekdays: only the selected days are scheduled; a mark on a day off does not count', () {
      expect(score(mwf, days(monday, 3)), const WeeklyConsistency(completedDays: 2, eligibleDays: 3));
    });

    test('weekdays: future selected days are not missed', () {
      expect(
        score(mwf, days(monday, 2), today: monday.addDays(1)),
        const WeeklyConsistency(completedDays: 1, eligibleDays: 1),
      );
    });

    test('weekly target: marks beyond the target do not count', () {
      final result = score(HabitSchedule.weeklyTarget(3), days(monday, 5));
      expect(result, const WeeklyConsistency(completedDays: 3, eligibleDays: 3));
      expect(result.percentage, 100);
    });

    test('weekly target: progress towards the target', () {
      expect(
        score(HabitSchedule.weeklyTarget(3), [monday.addDays(1)]),
        const WeeklyConsistency(completedDays: 1, eligibleDays: 3),
      );
    });

    test('weekly target: a new week starts on Monday', () {
      expect(
        score(HabitSchedule.weeklyTarget(3), days(monday, 5), today: sunday.addDays(1)),
        const WeeklyConsistency(completedDays: 0, eligibleDays: 3),
      );
    });

    test('a schedule does not score a period that has not started', () {
      final result = WeeklyConsistency.compute(
        today: sunday,
        joinedOn: sunday.addDays(1),
        habitCreatedAt: longAgo,
        completedDays: [sunday],
        schedule: HabitSchedule.weeklyTarget(3),
      );
      expect(result.isScored, isFalse);
    });
  });
}
