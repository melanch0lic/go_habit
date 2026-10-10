import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_habit/feature/notifications/domain/models/app_notification.dart';
import 'package:go_habit/feature/notifications/domain/models/reminder_settings.dart';
import 'package:go_habit/feature/notifications/domain/notification_plan.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// A notification the operating system holds: scheduled (pending) or on screen
/// (active).
@immutable
class SystemNotification {
  final int id;
  final String? payload;

  const SystemNotification(this.id, this.payload);
}

/// Localized names of the Android notification channels.
typedef ChannelNames = ({String habits, String habitsDescription, String progress, String progressDescription});

/// The operating system's notification APIs. [PluginNotificationGateway] uses
/// flutter_local_notifications; tests use a fake.
abstract interface class NotificationGateway {
  /// Prepares the plugin and the time zone database. Never asks for permission.
  /// [onTap] receives the payload of a notification the user opened while the app
  /// was running or in the background.
  Future<void> initialize({required void Function(String? payload) onTap});

  /// The payload of the notification that launched the app, if one did.
  Future<String?> launchPayload();

  /// The device's IANA time zone, e.g. `Europe/Moscow`. Also makes it the local zone
  /// for scheduling.
  Future<String> refreshTimeZone();

  Future<void> createChannels(ChannelNames names);

  /// [requestedBefore]: the app already showed the system prompt once.
  Future<NotificationPermission> permission({required bool requestedBefore});

  /// Shows the system prompt where the platform allows it; true if granted.
  Future<bool> requestPermission();

  Future<void> openSystemSettings();

  Future<List<SystemNotification>> pending();

  Future<List<SystemNotification>> active();

  Future<void> schedule(PlannedNotification notification);

  Future<void> cancel(int id);
}

/// Android channels. Habit reminders are default importance (sound, no heads-up
/// interruption); daily progress and streak reminders are low-key.
abstract final class NotificationChannels {
  static const habits = 'habit_reminders';
  static const progress = 'progress_reminders';

  static String of(NotificationCategory category) => category == NotificationCategory.habitReminder ? habits : progress;
}

/// The next time [notification] should fire after [now], in [now]'s location.
/// Repeating notifications are anchored to this first occurrence and then repeat on
/// the platform at the same local wall-clock time, also across daylight saving
/// changes. Null for a one-off whose time has passed.
tz.TZDateTime? nextOccurrence(PlannedNotification notification, tz.TZDateTime now) {
  final time = notification.time;
  tz.TZDateTime at(int year, int month, int day) =>
      tz.TZDateTime(now.location, year, month, day, time.hour, time.minute);

  switch (notification.repeat) {
    case NotificationRepeat.once:
      final date = notification.date!;
      final when = at(date.year, date.month, date.day);
      return when.isAfter(now) ? when : null;
    case NotificationRepeat.daily:
      var when = at(now.year, now.month, now.day);
      if (!when.isAfter(now)) when = at(now.year, now.month, now.day + 1);
      return when;
    case NotificationRepeat.weekly:
      final weekday = notification.weekday!;
      var days = (weekday - now.weekday) % 7;
      var when = at(now.year, now.month, now.day + days);
      if (!when.isAfter(now)) {
        days += 7;
        when = at(now.year, now.month, now.day + days);
      }
      return when;
  }
}

class PluginNotificationGateway implements NotificationGateway {
  final FlutterLocalNotificationsPlugin _plugin;

  PluginNotificationGateway([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  @override
  Future<void> initialize({required void Function(String? payload) onTap}) async {
    tz_data.initializeTimeZones();
    if (!_supported) return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is asked later, when the user turns a reminder on.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
  }

  @override
  Future<String?> launchPayload() async {
    if (!_supported) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false ? details?.notificationResponse?.payload : null;
  }

  @override
  Future<String> refreshTimeZone() async {
    var name = 'UTC';
    try {
      name = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(name));
    } on Object {
      // Unknown zone or no plugin (tests): keep UTC rather than failing.
      name = 'UTC';
      tz.setLocalLocation(tz.UTC);
    }
    return name;
  }

  @override
  Future<void> createChannels(ChannelNames names) async {
    final android = _android;
    if (android == null) return;
    await android.createNotificationChannel(AndroidNotificationChannel(
      NotificationChannels.habits,
      names.habits,
      description: names.habitsDescription,
    ));
    await android.createNotificationChannel(AndroidNotificationChannel(
      NotificationChannels.progress,
      names.progress,
      description: names.progressDescription,
      importance: Importance.low,
    ));
  }

  @override
  Future<NotificationPermission> permission({required bool requestedBefore}) async {
    if (!_supported) return NotificationPermission.unsupported;
    final bool granted;
    if (_android case final android?) {
      granted = await android.areNotificationsEnabled() ?? false;
    } else {
      granted = (await _ios?.checkPermissions())?.isEnabled ?? false;
    }
    if (granted) return NotificationPermission.granted;
    return requestedBefore ? NotificationPermission.denied : NotificationPermission.notRequested;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    if (_android case final android?) return await android.requestNotificationsPermission() ?? false;
    return await _ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  @override
  Future<void> openSystemSettings() => AppSettings.openAppSettings(type: AppSettingsType.notification);

  @override
  Future<List<SystemNotification>> pending() async {
    if (!_supported) return const [];
    return [
      for (final request in await _plugin.pendingNotificationRequests()) SystemNotification(request.id, request.payload)
    ];
  }

  @override
  Future<List<SystemNotification>> active() async {
    if (!_supported) return const [];
    return [
      for (final notification in await _plugin.getActiveNotifications())
        if (notification.id case final id?) SystemNotification(id, notification.payload),
    ];
  }

  @override
  Future<void> schedule(PlannedNotification notification) async {
    if (!_supported) return;
    final when = nextOccurrence(notification, tz.TZDateTime.now(tz.local));
    if (when == null) return;
    final channel = NotificationChannels.of(notification.category);
    await _plugin.zonedSchedule(
      notification.id,
      notification.title,
      notification.body,
      when,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channel,
          category: AndroidNotificationCategory.reminder,
          // The lock screen hides habit names unless the user allows private content.
          visibility: NotificationVisibility.private,
          importance: channel == NotificationChannels.habits ? Importance.defaultImportance : Importance.low,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      // No exact-alarm permission: the system may shift delivery slightly to save
      // battery, which suits reminders.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: notification.payload,
      matchDateTimeComponents: switch (notification.repeat) {
        NotificationRepeat.daily => DateTimeComponents.time,
        NotificationRepeat.weekly => DateTimeComponents.dayOfWeekAndTime,
        NotificationRepeat.once => null,
      },
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (!_supported) return;
    await _plugin.cancel(id);
  }
}

/// Minutes of a [TimeOfDay], for storage.
int minuteOf(TimeOfDay time) => time.hour * 60 + time.minute;

TimeOfDay timeOfMinute(int minute) => TimeOfDay(hour: minute ~/ 60 % 24, minute: minute % 60);
