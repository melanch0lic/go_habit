import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/feature/notifications/data/notification_gateway.dart';
import 'package:go_habit/feature/notifications/domain/models/app_notification.dart';
import 'package:go_habit/feature/notifications/domain/models/reminder_settings.dart';
import 'package:go_habit/feature/notifications/domain/notification_plan.dart';
import 'package:go_habit/feature/notifications/notification_service.dart';
import 'package:go_habit/l10n/app_localizations.dart';
import 'package:go_habit/l10n/app_localizations_ru.dart';

import '../habits/habits_fakes.dart';
import 'notification_fakes.dart';

AppLocalizations lookupL10n() => AppLocalizationsRu();

void main() {
  late FakeGateway gateway;
  late FakeNotificationRepository repository;
  late FakeHabitRepository habits;
  late FakeStatsRepository stats;
  late NotificationService service;
  var clock = DateTime(2026, 10, 9, 12);

  HabitReminder reminder(String id, {Set<int> days = HabitReminder.allDays, int hour = 9, bool enabled = true}) =>
      HabitReminder(habitId: id, time: TimeOfDay(hour: hour, minute: 0), weekdays: days, enabled: enabled);

  Future<void> settle() async {
    await pumpEventQueue();
    await service.reconcile();
  }

  Future<void> start({
    List<String> habitIds = const ['a'],
    List<HabitReminder>? reminders,
    NotificationPreferences preferences = const NotificationPreferences(),
  }) async {
    gateway = FakeGateway();
    repository = FakeNotificationRepository(preferences: preferences, reminders: reminders ?? [reminder('a')]);
    habits = FakeHabitRepository([for (final id in habitIds) habit(id)]);
    stats = FakeStatsRepository();
    service = NotificationService(
      gateway: gateway,
      repository: repository,
      habits: habits,
      stats: stats,
      now: () => clock,
      debounce: Duration.zero,
    );
    await service.start();
    await settle();
  }

  setUp(() => clock = DateTime(2026, 10, 9, 12));

  tearDown(() async {
    await service.dispose();
    await repository.dispose();
    await habits.dispose();
    await stats.dispose();
  });

  int scheduleCalls() => gateway.log.where((entry) => entry.startsWith('schedule')).length;

  group('scheduling', () {
    test('a daily reminder is scheduled once with a stable id', () async {
      await start();
      final scheduled = gateway.scheduled.values.single;
      expect((scheduled.repeat, scheduled.habitId), (NotificationRepeat.daily, 'a'));
      expect(scheduled.payload, contains('Europe/Moscow'));
    });

    test('reconciling again does not schedule anything new (idempotent)', () async {
      await start(reminders: [
        reminder('a', days: {1, 3, 5})
      ]);
      final calls = scheduleCalls();
      await service.reconcile();
      await service.reconcile();
      expect(scheduleCalls(), calls);
      expect(gateway.scheduled, hasLength(3));
    });

    test('changing the time replaces the notification instead of adding one', () async {
      await start();
      final id = gateway.scheduled.keys.single;
      await repository.saveReminder(reminder('a', hour: 18));
      await settle();
      expect(gateway.scheduled.keys, [id]);
      expect(gateway.scheduled[id]!.time, const TimeOfDay(hour: 18, minute: 0));
    });

    test('fewer days cancel the dropped ones', () async {
      await start(reminders: [
        reminder('a', days: {1, 3, 5})
      ]);
      await repository.saveReminder(reminder('a', days: {3}));
      await settle();
      expect(gateway.scheduled.values.map((n) => n.weekday), [3]);
    });

    test('disabling a reminder cancels it', () async {
      await start();
      await repository.saveReminder(reminder('a', enabled: false));
      await settle();
      expect(gateway.scheduled, isEmpty);
    });

    test('pausing or deleting the habit cancels its reminders; obsolete settings are pruned', () async {
      await start(habitIds: ['a', 'b'], reminders: [reminder('a'), reminder('b')]);
      expect(gateway.scheduled, hasLength(2));
      await habits.updateHabit(habit('a', active: false));
      await settle();
      expect(gateway.scheduled.values.map((n) => n.habitId), ['b']);
      await habits.deleteHabit('b');
      await settle();
      expect(gateway.scheduled, isEmpty);
      expect(repository.reminders.keys, ['a'], reason: "the deleted habit's reminder is gone; the paused one is kept");
    });

    test('renaming a habit updates the text of its reminder', () async {
      await start();
      await habits.updateHabit(habit('a', title: 'Новое имя'));
      await settle();
      expect(gateway.scheduled.values.single.body, contains('Новое имя'));
    });

    test('the master switch cancels everything and restores only what is enabled', () async {
      await start(habitIds: ['a', 'b'], reminders: [reminder('a'), reminder('b', enabled: false)]);
      await repository.savePreferences(const NotificationPreferences(enabled: false));
      await settle();
      expect(gateway.scheduled, isEmpty);
      await repository.savePreferences(const NotificationPreferences());
      await settle();
      expect(gateway.scheduled.values.map((n) => n.habitId), ['a']);
    });

    test('without permission nothing is scheduled, and it recovers once granted', () async {
      await start();
      gateway.systemPermission = NotificationPermission.denied;
      await service.reconcile();
      expect(gateway.scheduled, isEmpty, reason: 'no pretending that reminders are active');
      gateway.systemPermission = NotificationPermission.granted;
      await service.onResume();
      await settle();
      expect(gateway.scheduled, hasLength(1));
    });

    test('one failing notification does not stop the others', () async {
      await start(habitIds: ['a', 'b'], reminders: [reminder('a'), reminder('b')]);
      final ids = gateway.scheduled.keys.toList();
      gateway.scheduled.clear();
      gateway.failingIds.add(ids.first);
      await service.reconcile();
      expect(gateway.scheduled.keys, [ids.last]);
    });

    test('a time zone change reschedules under the new zone', () async {
      await start();
      gateway.timeZone = 'Asia/Tokyo';
      await service.onResume();
      await settle();
      expect(gateway.scheduled.values.single.payload, contains('Asia/Tokyo'));
      expect(gateway.scheduled, hasLength(1));
    });

    test("completing the last habit of the day withdraws today's progress reminder", () async {
      await start(preferences: const NotificationPreferences(dailyProgress: true));
      expect(gateway.scheduled.containsKey(NotificationIds.dailyProgressBase), isTrue);
      await stats.setCompleted(habitId: 'a', day: today, completed: true);
      await settle();
      expect(gateway.scheduled.containsKey(NotificationIds.dailyProgressBase), isFalse);
      expect(gateway.scheduled.containsKey(NotificationIds.dailyProgressBase + 1), isTrue, reason: 'tomorrow stays');
    });

    test('a weekly-target habit is reminded on its own chosen days', () async {
      gateway = FakeGateway();
      await start(reminders: [
        reminder('a', days: {2, 4})
      ]);
      await habits.updateHabit(habit('a').copyWith(schedule: HabitSchedule.weeklyTarget(3)));
      await settle();
      expect(gateway.scheduled.values.map((n) => n.weekday).toSet(), {2, 4});
    });
  });

  group('permission', () {
    test('the system prompt is shown once; later only the settings can help', () async {
      await start();
      gateway
        ..systemPermission = NotificationPermission.notRequested
        ..grantOnRequest = false;
      expect(await service.requestPermission(), NotificationPermission.denied);
      expect(await service.requestPermission(), NotificationPermission.denied);
      expect(gateway.log.where((e) => e == 'request'), hasLength(1));
      expect((await repository.getPreferences()).permissionRequested, isTrue);
    });
  });

  group('history and taps', () {
    String payloadFor(String habitId) {
      final planned = planNotifications(
        now: clock,
        preferences: const NotificationPreferences(),
        habits: [habit(habitId)],
        reminders: {habitId: reminder(habitId)},
        completions: const {},
        l10n: lookupL10n(),
        timeZone: 'UTC',
      ).single;
      return planned.payload;
    }

    test('a notification on screen is recorded once, unread', () async {
      await start();
      gateway.shown.add(SystemNotification(1000, payloadFor('a')));
      await service.onResume();
      await service.onResume();
      final record = repository.history.single;
      expect(record.isRead, isFalse);
      expect(record.category, NotificationCategory.habitReminder);
      expect(record.createdAt, DateTime(2026, 10, 9, 9), reason: 'when it fired, not when it was seen');
    });

    test('tapping records it as read, keeps one record and leads to the habit', () async {
      await start();
      gateway.shown.add(SystemNotification(1000, payloadFor('a')));
      await service.onResume();
      final tap = service.taps.first;
      gateway.tap(payloadFor('a'));
      final result = await tap;
      expect((result.habitId, result.habitExists), ('a', true));
      expect(repository.history.single.isRead, isTrue);
      expect(stats.writes, isEmpty, reason: 'opening a reminder never completes the habit');
    });

    test('a tap on a deleted habit is handled gracefully', () async {
      await start();
      await habits.deleteHabit('a');
      final tap = service.taps.first;
      gateway.tap(payloadFor('a'));
      expect((await tap).habitExists, isFalse);
    });

    test('an unreadable payload is ignored', () async {
      await start();
      gateway.tap('garbage');
      await pumpEventQueue();
      expect(repository.history, isEmpty);
    });

    test('the tap that launched the app is delivered once', () async {
      gateway = FakeGateway();
      repository = FakeNotificationRepository(reminders: [reminder('a')]);
      habits = FakeHabitRepository([habit('a')]);
      stats = FakeStatsRepository();
      gateway.launch = payloadFor('a');
      service = NotificationService(
        gateway: gateway,
        repository: repository,
        habits: habits,
        stats: stats,
        now: () => clock,
        debounce: Duration.zero,
      );
      await service.start();
      expect(service.takeLaunchTap()?.habitId, 'a');
      expect(service.takeLaunchTap(), isNull);
    });

    test('the language changes notification texts and channel names', () async {
      await start();
      service.setLocale('en');
      await settle();
      expect(gateway.scheduled.values.single.title, 'Time for your habit');
      expect(gateway.channels?.habits, 'Habit reminders');
    });
  });
}
