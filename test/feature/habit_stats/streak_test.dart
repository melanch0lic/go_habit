import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/habit_stats/domain/streak.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';

void main() {
  // Friday; the week runs Monday 2026-10-05 .. Sunday 2026-10-11.
  final today = CalendarDay(2026, 10, 9);
  List<CalendarDay> daysAgo(List<int> offsets) => [for (final o in offsets) today.addDays(-o)];

  group('daily', () {
    int streak(List<CalendarDay> days, {CalendarDay? on, CalendarDay? resetOn}) => computeStreak(
          schedule: HabitSchedule.daily,
          completedDays: days,
          today: on ?? today,
          resetOn: resetOn,
        ).count;

    test('is counted in days', () {
      expect(
        computeStreak(schedule: HabitSchedule.daily, completedDays: daysAgo([0]), today: today),
        const HabitStreak(1, StreakUnit.days),
      );
    });

    test('no completions means no streak', () => expect(streak([]), 0));

    test('counts consecutive days ending today', () => expect(streak(daysAgo([0, 1, 2])), 3));

    test("today is in progress: not done yet keeps yesterday's streak", () {
      expect(streak(daysAgo([1, 2, 3])), 3);
    });

    test('a missed day breaks the streak', () {
      expect(streak(daysAgo([0, 1, 3, 4])), 2);
      expect(streak(daysAgo([2, 3])), 0);
    });

    test('duplicates and order do not matter', () => expect(streak(daysAgo([1, 0, 1, 0])), 2));

    test('future marks are ignored', () => expect(streak(daysAgo([-1, 1])), 1));

    test('completions before the reset day do not count', () {
      expect(streak(daysAgo([0, 1, 2, 3]), resetOn: today.addDays(-1)), 2);
      expect(streak(daysAgo([1, 2]), resetOn: today), 0, reason: 'a reset today starts from zero');
    });

    test('daylight-saving changes do not break a streak', () {
      // Europe switches on 2026-03-29 and 2026-10-25; the US on 2026-03-08 and 2026-11-01.
      for (final change in [CalendarDay(2026, 3, 29), CalendarDay(2026, 10, 25), CalendarDay(2026, 11, 1)]) {
        final on = change.addDays(2);
        expect(streak([for (var i = 0; i < 5; i++) on.addDays(-i)], on: on), 5, reason: '$change');
      }
    });
  });

  group('weekly target', () {
    final schedule = HabitSchedule.weeklyTarget(3);
    HabitStreak streak(List<CalendarDay> days, {CalendarDay? on, CalendarDay? resetOn, HabitSchedule? rule}) =>
        computeStreak(schedule: rule ?? schedule, completedDays: days, today: on ?? today, resetOn: resetOn);
    final monday = today.weekStart;
    List<CalendarDay> week(int weeksAgo, List<int> weekdays) =>
        [for (final d in weekdays) monday.addDays(-7 * weeksAgo + d - 1)];

    test('is counted in weeks', () => expect(streak(week(1, [1, 2, 3])).unit, StreakUnit.weeks));

    test('consecutive successful weeks count; the current week is in progress', () {
      final history = [
        ...week(1, [1, 3, 5]),
        ...week(2, [2, 4, 6]),
        ...week(0, [1])
      ];
      expect(streak(history).count, 2, reason: 'this week has 1 of 3, which does not break the streak yet');
    });

    test('the current week counts once the target is reached', () {
      expect(
          streak([
            ...week(1, [1, 2, 3]),
            ...week(0, [1, 2, 3])
          ]).count,
          2);
    });

    test('a week below the target breaks the streak', () {
      expect(
          streak([
            ...week(1, [1, 2, 3]),
            ...week(2, [1, 2]),
            ...week(3, [1, 2, 3])
          ]).count,
          1);
      expect(streak(week(2, [1, 2, 3])).count, 0, reason: 'last week had no marks');
    });

    test('marks beyond the target are not extra units', () {
      expect(streak(week(1, [1, 2, 3, 4, 5, 6, 7])).count, 1);
    });

    test('future marks do not complete the current week', () {
      // Saturday and Sunday of this week are in the future.
      expect(streak(week(0, [1, 6, 7])).count, 0);
    });

    test('weeks run Monday to Sunday', () {
      // Sunday of last week and Monday, Tuesday of this week are not one week.
      final days = [monday.addDays(-1), monday, monday.addDays(1)];
      expect(streak(days).count, 0);
      expect(streak(days, on: monday.addDays(1)).count, 0);
    });

    test('a week across the new year is one week', () {
      final friday = CalendarDay(2027, 1, 1);
      expect(friday.weekStart, CalendarDay(2026, 12, 28));
      expect(streak([CalendarDay(2026, 12, 29), CalendarDay(2026, 12, 31), friday], on: friday).count, 1);
    });

    test('changing the target re-evaluates the history', () {
      final history = [
        ...week(1, [1, 2]),
        ...week(2, [1, 2])
      ];
      expect(streak(history).count, 0);
      expect(streak(history, rule: HabitSchedule.weeklyTarget(2)).count, 2);
    });

    test('weeks that end before the reset day do not count', () {
      final history = [
        ...week(1, [1, 2, 3]),
        ...week(2, [1, 2, 3])
      ];
      expect(streak(history, resetOn: monday.addDays(-7)).count, 1);
      expect(streak(history, resetOn: monday).count, 0);
    });

    test('marks before the reset day do not count within its week', () {
      // Reset on Wednesday: Monday and Tuesday of this week are not counted.
      expect(streak(week(0, [1, 2, 3, 4]), resetOn: monday.addDays(2)).count, 0);
      expect(streak(week(0, [1, 3, 4, 5]), resetOn: monday.addDays(2)).count, 1);
    });
  });

  group('selected weekdays', () {
    // Monday, Wednesday, Friday; today is Friday.
    final schedule = HabitSchedule.weekdays({DateTime.monday, DateTime.wednesday, DateTime.friday});
    final monday = today.weekStart;
    HabitStreak streak(List<CalendarDay> days, {CalendarDay? on, CalendarDay? resetOn}) =>
        computeStreak(schedule: schedule, completedDays: days, today: on ?? today, resetOn: resetOn);

    test('is counted in occurrences', () => expect(streak([today]).unit, StreakUnit.occurrences));

    test('counts consecutive scheduled days; days off are neutral', () {
      // Fri, Wed, Mon this week and Fri last week.
      expect(streak([today, monday.addDays(2), monday, monday.addDays(-3)]).count, 4);
    });

    test('a mark on a day off neither counts nor breaks', () {
      expect(streak([today, monday.addDays(3), monday.addDays(2)]).count, 2);
    });

    test('a missed scheduled day breaks the streak', () {
      // Wednesday is missing.
      expect(streak([today, monday, monday.addDays(-3)]).count, 1);
    });

    test('today is in progress: not done yet keeps the streak', () {
      expect(streak([monday.addDays(2), monday]).count, 2);
    });

    test('on a day off the streak is kept', () {
      final saturday = monday.addDays(5);
      expect(streak([today, monday.addDays(2)], on: saturday).count, 2);
    });

    test('future scheduled days are never missed', () {
      // On Wednesday, Friday is in the future.
      expect(streak([monday.addDays(2), monday], on: monday.addDays(2)).count, 2);
    });

    test('changing the days re-evaluates the history', () {
      final history = [today, monday.addDays(3), monday.addDays(1)];
      final tueThuFri = HabitSchedule.weekdays({DateTime.tuesday, DateTime.thursday, DateTime.friday});
      expect(streak(history).count, 1);
      expect(computeStreak(schedule: tueThuFri, completedDays: history, today: today).count, 3);
    });

    test('scheduled days before the reset day do not count', () {
      expect(streak([today, monday.addDays(2), monday], resetOn: monday.addDays(1)).count, 2);
    });
  });

  group('weekProgress', () {
    final monday = today.weekStart;
    final days = [monday, monday.addDays(1), monday.addDays(3), today, today.addDays(1)];

    test('daily: days marked out of days so far this week', () {
      expect(weekProgress(schedule: HabitSchedule.daily, completedDays: days, today: today), const WeekProgress(4, 5));
    });

    test('daily: a habit created this week counts from its creation', () {
      expect(
        weekProgress(
          schedule: HabitSchedule.daily,
          completedDays: days,
          today: today,
          createdAt: monday.addDays(2).toDateTime(),
        ),
        const WeekProgress(2, 3),
      );
    });

    test('weekly target: capped at the target, future marks ignored', () {
      final progress = weekProgress(schedule: HabitSchedule.weeklyTarget(3), completedDays: days, today: today);
      expect(progress, const WeekProgress(3, 3));
      expect(progress.reached, isTrue);
      expect(
        weekProgress(schedule: HabitSchedule.weeklyTarget(5), completedDays: days, today: today),
        const WeekProgress(4, 5),
      );
    });

    test('marks before the reset day are left out, like in the streak', () {
      expect(
        weekProgress(schedule: HabitSchedule.weeklyTarget(3), completedDays: days, today: today, resetOn: today),
        const WeekProgress(1, 3),
      );
    });

    test('weekdays: marked scheduled days out of the whole week', () {
      final schedule = HabitSchedule.weekdays({DateTime.monday, DateTime.wednesday, DateTime.friday});
      expect(weekProgress(schedule: schedule, completedDays: days, today: today), const WeekProgress(2, 3));
    });
  });
}
