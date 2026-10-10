import 'dart:async';

import 'package:go_habit/feature/notifications/data/notification_gateway.dart';
import 'package:go_habit/feature/notifications/data/notification_repository.dart';
import 'package:go_habit/feature/notifications/domain/models/app_notification.dart';
import 'package:go_habit/feature/notifications/domain/models/reminder_settings.dart';
import 'package:go_habit/feature/notifications/domain/notification_plan.dart';

/// The operating system's notification state, in memory.
class FakeGateway implements NotificationGateway {
  final scheduled = <int, PlannedNotification>{};
  final log = <String>[];
  final shown = <SystemNotification>[];
  NotificationPermission systemPermission = NotificationPermission.granted;
  bool grantOnRequest = true;
  String timeZone = 'Europe/Moscow';
  String? launch;
  ChannelNames? channels;

  /// Notification ids whose scheduling throws.
  final failingIds = <int>{};
  late void Function(String? payload) _onTap;

  /// Simulates the user tapping a notification while the app runs.
  void tap(String? payload) => _onTap(payload);

  @override
  Future<void> initialize({required void Function(String? payload) onTap}) async => _onTap = onTap;

  @override
  Future<String?> launchPayload() async => launch;

  @override
  Future<String> refreshTimeZone() async => timeZone;

  @override
  Future<void> createChannels(ChannelNames names) async => channels = names;

  @override
  Future<NotificationPermission> permission({required bool requestedBefore}) async =>
      systemPermission == NotificationPermission.notRequested && requestedBefore
          ? NotificationPermission.denied
          : systemPermission;

  @override
  Future<bool> requestPermission() async {
    log.add('request');
    systemPermission = grantOnRequest ? NotificationPermission.granted : NotificationPermission.denied;
    return grantOnRequest;
  }

  @override
  Future<void> openSystemSettings() async => log.add('settings');

  @override
  Future<List<SystemNotification>> pending() async =>
      [for (final MapEntry(:key, :value) in scheduled.entries) SystemNotification(key, value.payload)];

  @override
  Future<List<SystemNotification>> active() async => List.of(shown);

  @override
  Future<void> schedule(PlannedNotification notification) async {
    if (failingIds.contains(notification.id)) throw StateError('platform limit');
    log.add('schedule:${notification.id}');
    scheduled[notification.id] = notification;
  }

  @override
  Future<void> cancel(int id) async {
    log.add('cancel:$id');
    scheduled.remove(id);
  }
}

/// [NotificationRepository] in memory, with the same semantics as the Drift one.
class FakeNotificationRepository implements NotificationRepository {
  final _history = <String, AppNotification>{};
  final _reminders = <String, HabitReminder>{};
  NotificationPreferences _preferences;
  final _historyChanges = StreamController<List<AppNotification>>.broadcast();
  final _reminderChanges = StreamController<Map<String, HabitReminder>>.broadcast();
  final _preferenceChanges = StreamController<NotificationPreferences>.broadcast();
  DateTime now = DateTime(2026, 10, 9, 12);

  FakeNotificationRepository({
    NotificationPreferences preferences = const NotificationPreferences(),
    List<HabitReminder> reminders = const [],
    List<AppNotification> history = const [],
  }) : _preferences = preferences {
    for (final reminder in reminders) {
      _reminders[reminder.habitId] = reminder;
    }
    for (final item in history) {
      _history[item.id] = item;
    }
  }

  List<AppNotification> get history => _history.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  Map<String, HabitReminder> get reminders => Map.unmodifiable(_reminders);

  void _publishHistory() => _historyChanges.add(history);

  @override
  Stream<List<AppNotification>> watchHistory() async* {
    yield history;
    yield* _historyChanges.stream;
  }

  @override
  Future<bool> addToHistory(AppNotification notification) async {
    if (_history.containsKey(notification.id)) return false;
    _history[notification.id] = notification;
    _publishHistory();
    return true;
  }

  AppNotification _withRead(AppNotification item) => AppNotification(
        id: item.id,
        category: item.category,
        title: item.title,
        body: item.body,
        habitId: item.habitId,
        createdAt: item.createdAt,
        readAt: item.readAt ?? now,
      );

  @override
  Future<void> markRead(String id) async {
    if (_history[id] case final item?) _history[id] = _withRead(item);
    _publishHistory();
  }

  @override
  Future<void> markAllRead() async {
    _history.updateAll((_, item) => _withRead(item));
    _publishHistory();
  }

  @override
  Future<void> deleteFromHistory(String id) async {
    _history.remove(id);
    _publishHistory();
  }

  @override
  Future<void> clearHistory() async {
    _history.clear();
    _publishHistory();
  }

  @override
  Stream<Map<String, HabitReminder>> watchReminders() async* {
    yield reminders;
    yield* _reminderChanges.stream;
  }

  @override
  Future<Map<String, HabitReminder>> getReminders() async => reminders;

  @override
  Future<void> saveReminder(HabitReminder reminder) async {
    _reminders[reminder.habitId] = reminder;
    _reminderChanges.add(reminders);
  }

  @override
  Future<void> deleteReminder(String habitId) async {
    _reminders.remove(habitId);
    _reminderChanges.add(reminders);
  }

  @override
  Future<void> pruneReminders(Set<String> existingHabitIds) async {
    _reminders.removeWhere((id, _) => !existingHabitIds.contains(id));
    _reminderChanges.add(reminders);
  }

  @override
  Stream<NotificationPreferences> watchPreferences() async* {
    yield _preferences;
    yield* _preferenceChanges.stream;
  }

  @override
  Future<NotificationPreferences> getPreferences() async => _preferences;

  @override
  Future<void> savePreferences(NotificationPreferences preferences) async {
    _preferences = preferences;
    _preferenceChanges.add(preferences);
  }

  Future<void> dispose() async {
    await _historyChanges.close();
    await _reminderChanges.close();
    await _preferenceChanges.close();
  }
}
