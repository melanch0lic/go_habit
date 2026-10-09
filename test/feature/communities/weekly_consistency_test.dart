import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/communities/domain/weekly_consistency.dart';

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
}
