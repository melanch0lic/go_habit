import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/feature/notifications/data/notification_gateway.dart';
import 'package:go_habit/feature/notifications/domain/models/app_notification.dart';
import 'package:go_habit/feature/notifications/domain/models/reminder_settings.dart';
import 'package:go_habit/feature/notifications/domain/notification_plan.dart';
import 'package:go_habit/l10n/app_localizations_en.dart';
import 'package:go_habit/l10n/app_localizations_ru.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// Friday 2026-10-09, 12:00.
final now = DateTime(2026, 10, 9, 12);
final today = CalendarDay(2026, 10, 9);
final l10n = AppLocalizationsRu();

Habit habit(String id, {String title = 'Чтение', HabitSchedule schedule = HabitSchedule.daily, bool active = true}) =>
    Habit(
        id: id,
        title: title,
        categoryId: 'education',
        icon: '📚',
        isActive: active,
        schedule: schedule,
        createdAt: DateTime(2026));

HabitReminder reminder(String id, {Set<int> days = HabitReminder.allDays, bool enabled = true, int hour = 9}) =>
    HabitReminder(habitId: id, time: TimeOfDay(hour: hour, minute: 0), weekdays: days, enabled: enabled);

List<PlannedNotification> plan({
  NotificationPreferences preferences = const NotificationPreferences(),
  List<Habit> habits = const [],
  List<HabitReminder> reminders = const [],
  Map<String, List<CalendarDay>> completions = const {},
  DateTime? at,
  String timeZone = 'Europe/Moscow',
}) =>
    planNotifications(
      now: at ?? now,
      preferences: preferences,
      habits: habits,
      reminders: {for (final reminder in reminders) reminder.habitId: reminder},
      completions: completions,
      l10n: l10n,
      timeZone: timeZone,
    );

void main() {
  group('habit reminders', () {
    test('every day: one daily notification with the habit name', () {
      final result = plan(habits: [habit('a')], reminders: [reminder('a')]);
      final single = result.single;
      expect(single.repeat, NotificationRepeat.daily);
      expect(single.category, NotificationCategory.habitReminder);
      expect(single.title, l10n.notifications_habit_title);
      expect(single.body, l10n.notifications_habit_body('📚 Чтение'));
      expect(single.habitId, 'a');
      expect(single.time, const TimeOfDay(hour: 9, minute: 0));
    });

    test('selected weekdays: one weekly notification per day', () {
      final result = plan(habits: [
        habit('a')
      ], reminders: [
        reminder('a', days: {1, 3, 5})
      ]);
      expect(result.map((n) => (n.repeat, n.weekday)), [
        (NotificationRepeat.weekly, 1),
        (NotificationRepeat.weekly, 3),
        (NotificationRepeat.weekly, 5),
      ]);
      expect(result.map((n) => n.id).toSet(), hasLength(3), reason: 'distinct ids');
    });

    test("a weekly target uses the reminder's own days, not the schedule", () {
      final weekly = habit('a', schedule: HabitSchedule.weeklyTarget(3));
      final result = plan(habits: [
        weekly
      ], reminders: [
        reminder('a', days: {2, 6})
      ]);
      expect(result.map((n) => n.weekday), [2, 6]);
    });

    test('disabled reminders, paused habits, missing habits and the master switch plan nothing', () {
      expect(plan(habits: [habit('a')], reminders: [reminder('a', enabled: false)]), isEmpty);
      expect(plan(habits: [habit('a', active: false)], reminders: [reminder('a')]), isEmpty);
      expect(plan(reminders: [reminder('deleted')]), isEmpty);
      expect(
        plan(
          preferences: const NotificationPreferences(enabled: false, dailyProgress: true, streakRisk: true),
          habits: [habit('a')],
          reminders: [reminder('a')],
        ),
        isEmpty,
      );
    });

    test('planning again gives the same ids and payloads; a rename keeps the id', () {
      final first = plan(habits: [
        habit('a'),
        habit('b')
      ], reminders: [
        reminder('a'),
        reminder('b', days: {1})
      ]);
      final second = plan(habits: [
        habit('b'),
        habit('a')
      ], reminders: [
        reminder('b', days: {1}),
        reminder('a')
      ]);
      expect(second.map((n) => (n.id, n.payload)), first.map((n) => (n.id, n.payload)));

      final renamed = plan(habits: [habit('a', title: 'Книги')], reminders: [reminder('a')]).single;
      expect(renamed.id, first.firstWhere((n) => n.habitId == 'a').id);
      expect(renamed.body, contains('Книги'), reason: 'never stale content');
    });

    test('texts follow the app language', () {
      final english = planNotifications(
        now: now,
        preferences: const NotificationPreferences(),
        habits: [habit('a', title: 'Reading')],
        reminders: {'a': reminder('a')},
        completions: const {},
        l10n: AppLocalizationsEn(),
        timeZone: 'UTC',
      ).single;
      expect(english.title, 'Time for your habit');
    });

    test('colliding slots are resolved deterministically', () {
      final slots = NotificationIds.habitSlots(['x', 'y', 'z']);
      expect(slots.values.toSet(), hasLength(3));
      expect(NotificationIds.habitSlots(['z', 'y', 'x']), slots);
      expect(NotificationIds.habit(slots['x']!, weekday: 7) - NotificationIds.habit(slots['x']!), 7);
    });

    test('at most the platform limit is planned', () {
      final habits = [for (var i = 0; i < 20; i++) habit('h$i')];
      final reminders = [
        for (var i = 0; i < 20; i++) reminder('h$i', days: {1, 2, 3, 4, 5})
      ];
      expect(plan(habits: habits, reminders: reminders), hasLength(maxPendingNotifications));
    });
  });

  group('daily progress', () {
    const on = NotificationPreferences(dailyProgress: true);

    test('today, with the number of habits left, and later days with a general text', () {
      final result = plan(preferences: on, habits: [
        habit('a'),
        habit('b')
      ], completions: {
        'a': [today],
      });
      expect(result.map((n) => n.id), [for (var i = 0; i < dailyProgressHorizonDays; i++) 100 + i]);
      expect(result.first.body, l10n.notifications_progress_body(1));
      expect(result.first.date, today);
      expect(result[1].body, l10n.notifications_progress_body_general);
      expect(result.every((n) => n.repeat == NotificationRepeat.once), isTrue);
    });

    test('skipped today when everything is done or the time has passed', () {
      final done = plan(preferences: on, habits: [
        habit('a')
      ], completions: {
        'a': [today],
      });
      expect(done.any((n) => n.date == today), isFalse, reason: 'not redundant');
      final late = plan(preferences: on, habits: [habit('a')], at: DateTime(2026, 10, 9, 21));
      expect(late.any((n) => n.date == today), isFalse);
    });

    test('only days with something scheduled', () {
      final mondays = habit('a', schedule: HabitSchedule.weekdays({DateTime.monday}));
      final result = plan(preferences: on, habits: [mondays]);
      expect(result.map((n) => n.date), [CalendarDay(2026, 10, 12)]);
      expect(plan(preferences: on, habits: [habit('b', schedule: HabitSchedule.weeklyTarget(3))]), isEmpty,
          reason: 'a weekly target is not due on any particular day');
    });
  });

  group('streak warning', () {
    const on = NotificationPreferences(streakRisk: true);
    final yesterday = today.addDays(-1);

    test('a daily streak not continued today is at risk', () {
      final result = plan(preferences: on, habits: [
        habit('a')
      ], completions: {
        'a': [yesterday],
      });
      final warning = result.single;
      expect(warning.id, NotificationIds.streakRisk);
      expect(warning.body, l10n.notifications_streak_body_one('Чтение'));
      expect(warning.date, today);
    });

    test('no warning when done today, without a streak, after its time, or when not due', () {
      expect(
          plan(preferences: on, habits: [
            habit('a')
          ], completions: {
            'a': [yesterday, today]
          }),
          isEmpty);
      expect(plan(preferences: on, habits: [habit('a')]), isEmpty, reason: 'no streak, no risk');
      expect(
          plan(
              preferences: on,
              habits: [habit('a')],
              completions: {
                'a': [yesterday]
              },
              at: DateTime(2026, 10, 9, 22)),
          isEmpty);
      final mondays = habit('m', schedule: HabitSchedule.weekdays({DateTime.monday}));
      expect(
          plan(preferences: on, habits: [
            mondays
          ], completions: {
            'm': [CalendarDay(2026, 10, 5)]
          }),
          isEmpty,
          reason: 'Friday is not scheduled, so the streak is not at risk');
    });

    test('a weekly target is at risk only on the last day of the week', () {
      final weekly = habit('w', schedule: HabitSchedule.weeklyTarget(2));
      final lastWeek = [CalendarDay(2026, 9, 28), CalendarDay(2026, 9, 30)];
      expect(plan(preferences: on, habits: [weekly], completions: {'w': lastWeek}), isEmpty,
          reason: 'on Friday the week is still in progress');
      final sunday = DateTime(2026, 10, 11, 12);
      expect(plan(preferences: on, habits: [weekly], completions: {'w': lastWeek}, at: sunday), hasLength(1));
    });

    test('several habits at risk are summed up', () {
      final result = plan(preferences: on, habits: [
        habit('a'),
        habit('b')
      ], completions: {
        'a': [yesterday],
        'b': [yesterday],
      });
      expect(result.single.body, l10n.notifications_streak_body_many(2));
      expect(result.single.habitId, isNull);
    });
  });

  group('payload', () {
    test('round-trips and tells when the notification fired', () {
      final planned = plan(habits: [habit('a')], reminders: [reminder('a')]).single;
      final payload = NotificationPayload.tryParse(planned.payload)!;
      expect(
          (payload.category, payload.habitId, payload.title), (NotificationCategory.habitReminder, 'a', planned.title));
      expect(payload.occurredAt(now), DateTime(2026, 10, 9, 9));
      expect(payload.occurredAt(DateTime(2026, 10, 9, 8)), DateTime(2026, 10, 8, 9), reason: "yesterday's");
      expect(NotificationPayload.tryParse('not json'), isNull);
      expect(NotificationPayload.tryParse(null), isNull);
    });

    test('a time zone change changes the payload, so it is rescheduled', () {
      final moscow = plan(habits: [habit('a')], reminders: [reminder('a')]).single;
      final berlin = plan(habits: [habit('a')], reminders: [reminder('a')], timeZone: 'Europe/Berlin').single;
      expect(berlin.id, moscow.id);
      expect(berlin.payload, isNot(moscow.payload));
    });
  });

  group('next occurrence', () {
    setUpAll(tz_data.initializeTimeZones);
    tz.Location berlin() => tz.getLocation('Europe/Berlin');
    PlannedNotification at(NotificationRepeat repeat, {int? weekday, CalendarDay? date}) => PlannedNotification(
          id: 1000,
          category: NotificationCategory.habitReminder,
          title: '',
          body: '',
          repeat: repeat,
          time: const TimeOfDay(hour: 9, minute: 0),
          weekday: weekday,
          date: date,
          timeZone: 'Europe/Berlin',
        );

    test('daily: later today, or tomorrow once the time has passed', () {
      expect(nextOccurrence(at(NotificationRepeat.daily), tz.TZDateTime(berlin(), 2026, 10, 9, 8)),
          tz.TZDateTime(berlin(), 2026, 10, 9, 9));
      expect(nextOccurrence(at(NotificationRepeat.daily), tz.TZDateTime(berlin(), 2026, 10, 9, 9)),
          tz.TZDateTime(berlin(), 2026, 10, 10, 9));
    });

    test('weekly: the next matching weekday, across the week boundary', () {
      // Friday → Monday.
      expect(nextOccurrence(at(NotificationRepeat.weekly, weekday: 1), tz.TZDateTime(berlin(), 2026, 10, 9, 12)),
          tz.TZDateTime(berlin(), 2026, 10, 12, 9));
      // Friday after 9:00 → next Friday.
      expect(nextOccurrence(at(NotificationRepeat.weekly, weekday: 5), tz.TZDateTime(berlin(), 2026, 10, 9, 12)),
          tz.TZDateTime(berlin(), 2026, 10, 16, 9));
    });

    test('keeps the local wall-clock time across a daylight saving change', () {
      // Clocks go forward on 2026-03-29.
      final next = nextOccurrence(at(NotificationRepeat.daily), tz.TZDateTime(berlin(), 2026, 3, 28, 12))!;
      expect((next.day, next.hour), (29, 9));
      expect(next.timeZoneOffset, const Duration(hours: 2), reason: 'summer time');
    });

    test('a one-off in the past is not scheduled', () {
      final date = CalendarDay(2026, 10, 9);
      expect(nextOccurrence(at(NotificationRepeat.once, date: date), tz.TZDateTime(berlin(), 2026, 10, 9, 10)), isNull);
      expect(nextOccurrence(at(NotificationRepeat.once, date: date), tz.TZDateTime(berlin(), 2026, 10, 9, 8)),
          tz.TZDateTime(berlin(), 2026, 10, 9, 9));
    });
  });
}
