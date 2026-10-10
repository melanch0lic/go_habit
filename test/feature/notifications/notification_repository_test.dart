import 'package:drift/native.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/database/dao/notifications_dao.dart';
import 'package:go_habit/core/database/drift_database.dart';
import 'package:go_habit/feature/notifications/bloc/notification_center_bloc.dart';
import 'package:go_habit/feature/notifications/data/notification_repository.dart';
import 'package:go_habit/feature/notifications/domain/models/app_notification.dart';
import 'package:go_habit/feature/notifications/domain/models/reminder_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_fakes.dart';

AppNotification record(String id, {DateTime? at, bool read = false}) => AppNotification(
      id: id,
      category: NotificationCategory.habitReminder,
      title: 'Время для привычки',
      body: 'Чтение',
      habitId: 'a',
      createdAt: at ?? DateTime(2026, 10, 9, 9),
      readAt: read ? DateTime(2026, 10, 9, 10) : null,
    );

void main() {
  group('LocalNotificationRepository', () {
    late AppDatabase db;
    late LocalNotificationRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      repository = LocalNotificationRepository(NotificationsDao(db), now: () => DateTime(2026, 10, 9, 12));
    });

    tearDown(() => db.close());

    test('history is stored newest first; a repeated event keeps one record and its read state', () async {
      expect(await repository.addToHistory(record('old', at: DateTime(2026, 10, 8))), isTrue);
      expect(await repository.addToHistory(record('new')), isTrue);
      await repository.markRead('new');
      expect(await repository.addToHistory(record('new')), isFalse, reason: 'duplicate event');

      final items = await repository.watchHistory().first;
      expect(items.map((item) => item.id), ['new', 'old']);
      expect(items.first.isRead, isTrue);
    });

    test('read, read all, delete one and clear', () async {
      for (final id in ['a', 'b', 'c']) {
        await repository.addToHistory(record(id));
      }
      await repository.markRead('a');
      expect((await repository.watchHistory().first).where((item) => !item.isRead), hasLength(2));
      await repository.markAllRead();
      expect((await repository.watchHistory().first).every((item) => item.isRead), isTrue);
      await repository.deleteFromHistory('b');
      expect((await repository.watchHistory().first).map((item) => item.id), unorderedEquals(['a', 'c']));
      await repository.clearHistory();
      expect(await repository.watchHistory().first, isEmpty);
    });

    test('an unknown stored category reads as system', () async {
      await db.into(db.notificationHistory).insert(NotificationHistoryCompanion.insert(
            id: 'x',
            category: 'friend_request',
            title: 't',
            body: 'b',
            createdAt: DateTime(2026),
          ));
      expect((await repository.watchHistory().first).single.category, NotificationCategory.system);
    });

    test('reminders round-trip, are replaced in place and pruned with their habits', () async {
      final reminder = HabitReminder(habitId: 'a', time: const TimeOfDay(hour: 7, minute: 30), weekdays: {1, 3, 5});
      await repository.saveReminder(reminder);
      await repository
          .saveReminder(HabitReminder(habitId: 'b', time: const TimeOfDay(hour: 9, minute: 0), weekdays: {7}));
      expect((await repository.getReminders())['a'], reminder);

      await repository.saveReminder(reminder.copyWith(enabled: false));
      expect((await repository.getReminders())['a']!.enabled, isFalse);
      expect(await repository.getReminders(), hasLength(2), reason: 'no duplicate rows');

      await repository.pruneReminders({'a'});
      expect((await repository.getReminders()).keys, ['a']);
      await repository.deleteReminder('a');
      expect(await repository.getReminders(), isEmpty);
    });

    test('preferences persist across restarts and default to the safe values', () async {
      expect(await repository.getPreferences(), const NotificationPreferences());
      const changed = NotificationPreferences(
        enabled: false,
        dailyProgress: true,
        dailyProgressTime: TimeOfDay(hour: 19, minute: 15),
        streakRisk: true,
        permissionRequested: true,
      );
      await repository.savePreferences(changed);
      final restarted = LocalNotificationRepository(NotificationsDao(db));
      expect(await restarted.getPreferences(), changed);
    });

    test('signing in with another account clears reminders and history', () async {
      await repository.addToHistory(record('a'));
      await repository
          .saveReminder(HabitReminder(habitId: 'a', time: const TimeOfDay(hour: 9, minute: 0), weekdays: {1}));
      await db.clearUserData();
      expect(await repository.watchHistory().first, isEmpty);
      expect(await repository.getReminders(), isEmpty);
    });
  });

  group('NotificationCenterBloc', () {
    late FakeNotificationRepository repository;
    late NotificationCenterBloc bloc;

    setUp(() async {
      repository = FakeNotificationRepository(history: [
        record('a', at: DateTime(2026, 10, 9, 9)),
        record('b', at: DateTime(2026, 10, 8, 9), read: true),
      ]);
      bloc = NotificationCenterBloc(repository, now: () => DateTime(2026, 10, 9, 12))
        ..add(const NotificationCenterStarted());
      await pumpEventQueue();
    });

    tearDown(() async {
      await bloc.close();
      await repository.dispose();
    });

    test('loads the history and counts unread items', () {
      expect(bloc.state.status, NotificationCenterStatus.ready);
      expect(bloc.state.items.map((item) => item.id), ['a', 'b']);
      expect(bloc.state.unreadCount, 1);
    });

    test('changes show at once and are persisted', () async {
      bloc.add(const NotificationsAllRead());
      await pumpEventQueue();
      expect(bloc.state.unreadCount, 0);
      expect(repository.history.every((item) => item.isRead), isTrue);

      bloc.add(const NotificationDeleted('a'));
      await pumpEventQueue();
      expect(bloc.state.items.map((item) => item.id), ['b']);
      expect(repository.history.map((item) => item.id), ['b']);

      bloc.add(const NotificationHistoryCleared());
      await pumpEventQueue();
      expect(bloc.state.items, isEmpty);
      expect(repository.history, isEmpty);
    });

    test('reading one marks only that one', () async {
      bloc.add(const NotificationRead('a'));
      await pumpEventQueue();
      expect(bloc.state.unreadCount, 0);
      expect(repository.history.firstWhere((item) => item.id == 'a').isRead, isTrue);
    });
  });
}
