import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/database/drift_database.dart' as db;
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';

void main() {
  group('HabitSchedule', () {
    test('weekdays are stored as a bit per day, Monday first', () {
      final mwf = HabitSchedule.weekdays({DateTime.monday, DateTime.wednesday, DateTime.friday});
      expect(mwf.daysMask, 21);
      expect(HabitSchedule.weekdays({DateTime.sunday}).daysMask, 64);
      expect(HabitSchedule.daily.daysMask, isNull);
      expect(HabitSchedule.weeklyTarget(3).daysMask, isNull);
    });

    test('every schedule survives storage unchanged', () {
      final schedules = [
        HabitSchedule.daily,
        for (var target = 1; target <= 7; target++) HabitSchedule.weeklyTarget(target),
        HabitSchedule.weekdays({DateTime.monday}),
        HabitSchedule.weekdays({DateTime.saturday, DateTime.sunday}),
        HabitSchedule.weekdays({for (var d = 1; d <= 7; d++) d}),
      ];
      for (final schedule in schedules) {
        final restored = HabitSchedule.fromStorage(
          type: schedule.type.wire,
          weeklyTarget: schedule.weeklyTarget,
          daysMask: schedule.daysMask,
        );
        expect(restored, schedule);
      }
    });

    test('missing or inconsistent stored values fall back to daily', () {
      expect(HabitSchedule.fromStorage(), HabitSchedule.daily);
      expect(HabitSchedule.fromStorage(type: 'monthly'), HabitSchedule.daily);
      expect(HabitSchedule.fromStorage(type: 'weekly_target'), HabitSchedule.daily);
      expect(HabitSchedule.fromStorage(type: 'weekly_target', weeklyTarget: 8), HabitSchedule.daily);
      expect(HabitSchedule.fromStorage(type: 'weekdays', daysMask: 0), HabitSchedule.daily);
      expect(HabitSchedule.fromStorage(type: 'weekdays', daysMask: 128), HabitSchedule.daily);
    });

    test('invalid schedules cannot be created', () {
      expect(() => HabitSchedule.weeklyTarget(0), throwsArgumentError);
      expect(() => HabitSchedule.weeklyTarget(8), throwsArgumentError);
      expect(() => HabitSchedule.weekdays({}), throwsArgumentError);
      expect(() => HabitSchedule.weekdays({0}), throwsArgumentError);
    });

    test('what is due on a day', () {
      final friday = CalendarDay(2026, 10, 9);
      final saturday = friday.addDays(1);
      final mwf = HabitSchedule.weekdays({DateTime.monday, DateTime.wednesday, DateTime.friday});
      expect((mwf.isDueOn(friday), mwf.isDueOn(saturday)), (true, false));
      expect((mwf.countsOn(friday), mwf.countsOn(saturday)), (true, false));
      expect(HabitSchedule.daily.isDueOn(saturday), isTrue);
      final weekly = HabitSchedule.weeklyTarget(2);
      expect(weekly.isDueOn(friday), isFalse, reason: "a weekly target is not any one day's obligation");
      expect(weekly.countsOn(saturday), isTrue);
    });

    test('equality ignores the order of weekdays', () {
      expect(HabitSchedule.weekdays({1, 3}), HabitSchedule.weekdays({3, 1}));
      expect(HabitSchedule.weekdays({1, 3}).hashCode, HabitSchedule.weekdays({3, 1}).hashCode);
      expect(HabitSchedule.weeklyTarget(2), isNot(HabitSchedule.weeklyTarget(3)));
    });
  });

  test('a habit row maps to its schedule and reset day', () {
    final row = db.Habit(
      id: 'h1',
      title: 'Gym',
      categoryId: 'sport',
      isActive: true,
      steps: 0,
      icon: '🏋️',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      isPendingSync: false,
      localVersion: 0,
      scheduleType: 'weekdays',
      scheduleDays: 21,
      streakResetOn: '2026-10-05',
    );
    final habit = Habit.fromDriftModel(row);
    expect(habit.schedule, HabitSchedule.weekdays({DateTime.monday, DateTime.wednesday, DateTime.friday}));
    expect(habit.streakResetOn, CalendarDay(2026, 10, 5));
  });
}
