import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:go_habit/core/database/dao/notifications_dao.dart';
import 'package:go_habit/core/database/drift_database.dart';
import 'package:go_habit/feature/notifications/data/notification_gateway.dart';
import 'package:go_habit/feature/notifications/domain/models/app_notification.dart';
import 'package:go_habit/feature/notifications/domain/models/reminder_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local notification data: habit reminders and the history (Drift), and the app-wide
/// preferences (SharedPreferences). Nothing here needs the network.
abstract interface class NotificationRepository {
  Stream<List<AppNotification>> watchHistory();

  /// Adds [notification] unless a record with its id exists; true if added.
  Future<bool> addToHistory(AppNotification notification);
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> deleteFromHistory(String id);
  Future<void> clearHistory();

  Stream<Map<String, HabitReminder>> watchReminders();
  Future<Map<String, HabitReminder>> getReminders();
  Future<void> saveReminder(HabitReminder reminder);
  Future<void> deleteReminder(String habitId);

  /// Removes reminders of habits that are gone (e.g. deleted on another device).
  Future<void> pruneReminders(Set<String> existingHabitIds);

  Stream<NotificationPreferences> watchPreferences();
  Future<NotificationPreferences> getPreferences();
  Future<void> savePreferences(NotificationPreferences preferences);
}

class LocalNotificationRepository implements NotificationRepository {
  final NotificationsDao _dao;
  final Future<SharedPreferences> _prefs;
  final DateTime Function() _now;
  final _preferences = StreamController<NotificationPreferences>.broadcast();

  LocalNotificationRepository(this._dao, {Future<SharedPreferences>? prefs, DateTime Function()? now})
      : _prefs = prefs ?? SharedPreferences.getInstance(),
        _now = now ?? DateTime.now;

  static const _keyEnabled = 'notifications.enabled';
  static const _keyProgress = 'notifications.daily_progress';
  static const _keyProgressTime = 'notifications.daily_progress_minute';
  static const _keyStreak = 'notifications.streak_risk';
  static const _keyStreakTime = 'notifications.streak_risk_minute';
  static const _keyRequested = 'notifications.permission_requested';

  @override
  Stream<List<AppNotification>> watchHistory() => _dao.watchHistory().map((rows) => [
        for (final row in rows)
          AppNotification(
            id: row.id,
            category: NotificationCategory.parse(row.category),
            title: row.title,
            body: row.body,
            habitId: row.habitId,
            createdAt: row.createdAt,
            readAt: row.readAt,
          ),
      ]);

  @override
  Future<bool> addToHistory(AppNotification notification) => _dao.addOnce(NotificationHistoryCompanion.insert(
        id: notification.id,
        category: notification.category.wire,
        title: notification.title,
        body: notification.body,
        habitId: Value(notification.habitId),
        createdAt: notification.createdAt,
        readAt: Value(notification.readAt),
      ));

  @override
  Future<void> markRead(String id) => _dao.markRead(id, _now());

  @override
  Future<void> markAllRead() => _dao.markAllRead(_now());

  @override
  Future<void> deleteFromHistory(String id) => _dao.deleteEntry(id);

  @override
  Future<void> clearHistory() => _dao.clearHistory();

  static HabitReminder _reminder(HabitReminderEntry row) => HabitReminder(
        habitId: row.habitId,
        enabled: row.enabled,
        time: timeOfMinute(row.minuteOfDay),
        // A corrupt mask falls back to every day instead of failing.
        weekdays: row.daysMask & 127 == 0 ? HabitReminder.allDays : HabitReminder.daysFromMask(row.daysMask),
      );

  @override
  Stream<Map<String, HabitReminder>> watchReminders() =>
      _dao.watchReminders().map((rows) => {for (final row in rows) row.habitId: _reminder(row)});

  @override
  Future<Map<String, HabitReminder>> getReminders() async =>
      {for (final row in await _dao.getReminders()) row.habitId: _reminder(row)};

  @override
  Future<void> saveReminder(HabitReminder reminder) => _dao.saveReminder(HabitRemindersCompanion.insert(
        habitId: reminder.habitId,
        enabled: Value(reminder.enabled),
        minuteOfDay: reminder.minuteOfDay,
        daysMask: reminder.daysMask,
      ));

  @override
  Future<void> deleteReminder(String habitId) => _dao.deleteReminder(habitId);

  @override
  Future<void> pruneReminders(Set<String> existingHabitIds) => _dao.deleteRemindersExcept(existingHabitIds);

  @override
  Stream<NotificationPreferences> watchPreferences() async* {
    yield await getPreferences();
    yield* _preferences.stream;
  }

  @override
  Future<NotificationPreferences> getPreferences() async {
    final prefs = await _prefs;
    const defaults = NotificationPreferences();
    return NotificationPreferences(
      enabled: prefs.getBool(_keyEnabled) ?? defaults.enabled,
      dailyProgress: prefs.getBool(_keyProgress) ?? defaults.dailyProgress,
      dailyProgressTime: timeOfMinute(prefs.getInt(_keyProgressTime) ?? minuteOf(defaults.dailyProgressTime)),
      streakRisk: prefs.getBool(_keyStreak) ?? defaults.streakRisk,
      streakRiskTime: timeOfMinute(prefs.getInt(_keyStreakTime) ?? minuteOf(defaults.streakRiskTime)),
      permissionRequested: prefs.getBool(_keyRequested) ?? defaults.permissionRequested,
    );
  }

  @override
  Future<void> savePreferences(NotificationPreferences preferences) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyEnabled, preferences.enabled);
    await prefs.setBool(_keyProgress, preferences.dailyProgress);
    await prefs.setInt(_keyProgressTime, minuteOf(preferences.dailyProgressTime));
    await prefs.setBool(_keyStreak, preferences.streakRisk);
    await prefs.setInt(_keyStreakTime, minuteOf(preferences.streakRiskTime));
    await prefs.setBool(_keyRequested, preferences.permissionRequested);
    _preferences.add(preferences);
  }
}
