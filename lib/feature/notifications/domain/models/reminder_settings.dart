import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

/// A habit's reminder on this device: whether it is on, the local time and the days.
/// The days are chosen by the user and independent of the completion schedule (a
/// weekly target has no fixed days, so its reminder days are always explicit).
@immutable
class HabitReminder {
  final String habitId;
  final bool enabled;
  final TimeOfDay time;

  /// [DateTime.monday] … [DateTime.sunday]; never empty.
  final Set<int> weekdays;

  HabitReminder({required this.habitId, required this.time, required Set<int> weekdays, this.enabled = true})
      : assert(weekdays.isNotEmpty, 'a reminder needs at least one day'),
        weekdays = Set.unmodifiable(weekdays);

  static const allDays = {1, 2, 3, 4, 5, 6, 7};

  bool get everyDay => weekdays.length == 7;

  int get minuteOfDay => time.hour * 60 + time.minute;

  /// Bit (weekday - 1) per day.
  int get daysMask => weekdays.fold(0, (mask, day) => mask | (1 << (day - 1)));

  static Set<int> daysFromMask(int mask) => {
        for (var day = DateTime.monday; day <= DateTime.sunday; day++)
          if (mask & (1 << (day - 1)) != 0) day,
      };

  HabitReminder copyWith({bool? enabled, TimeOfDay? time, Set<int>? weekdays}) => HabitReminder(
        habitId: habitId,
        enabled: enabled ?? this.enabled,
        time: time ?? this.time,
        weekdays: weekdays ?? this.weekdays,
      );

  @override
  bool operator ==(Object other) =>
      other is HabitReminder &&
      other.habitId == habitId &&
      other.enabled == enabled &&
      other.time == time &&
      setEquals(other.weekdays, weekdays);

  @override
  int get hashCode => Object.hash(habitId, enabled, time, Object.hashAllUnordered(weekdays));
}

/// App-wide notification preferences, stored on the device.
@immutable
class NotificationPreferences {
  /// The app's own master switch (not the system permission). Off cancels every
  /// notification the app manages; on restores the ones still enabled below.
  final bool enabled;

  /// A daily reminder to review the day's habits; off by default.
  final bool dailyProgress;
  final TimeOfDay dailyProgressTime;

  /// An evening warning when an unfinished habit would end its streak today; off by
  /// default.
  final bool streakRisk;
  final TimeOfDay streakRiskTime;

  /// The system permission prompt was shown once already (it is not shown again).
  final bool permissionRequested;

  const NotificationPreferences({
    this.enabled = true,
    this.dailyProgress = false,
    this.dailyProgressTime = const TimeOfDay(hour: 20, minute: 0),
    this.streakRisk = false,
    this.streakRiskTime = const TimeOfDay(hour: 21, minute: 0),
    this.permissionRequested = false,
  });

  NotificationPreferences copyWith({
    bool? enabled,
    bool? dailyProgress,
    TimeOfDay? dailyProgressTime,
    bool? streakRisk,
    TimeOfDay? streakRiskTime,
    bool? permissionRequested,
  }) =>
      NotificationPreferences(
        enabled: enabled ?? this.enabled,
        dailyProgress: dailyProgress ?? this.dailyProgress,
        dailyProgressTime: dailyProgressTime ?? this.dailyProgressTime,
        streakRisk: streakRisk ?? this.streakRisk,
        streakRiskTime: streakRiskTime ?? this.streakRiskTime,
        permissionRequested: permissionRequested ?? this.permissionRequested,
      );

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.enabled == enabled &&
      other.dailyProgress == dailyProgress &&
      other.dailyProgressTime == dailyProgressTime &&
      other.streakRisk == streakRisk &&
      other.streakRiskTime == streakRiskTime &&
      other.permissionRequested == permissionRequested;

  @override
  int get hashCode =>
      Object.hash(enabled, dailyProgress, dailyProgressTime, streakRisk, streakRiskTime, permissionRequested);
}

/// Whether the system lets the app show notifications.
enum NotificationPermission {
  granted,

  /// Not granted yet; asking may show the system prompt.
  notRequested,

  /// Refused; only the system settings can change it.
  denied,

  /// The platform does not support local notifications (e.g. tests, web).
  unsupported,
}

/// A reminder as edited in the habit form, before the habit has an id.
@immutable
class ReminderDraft {
  final bool enabled;
  final TimeOfDay time;
  final Set<int> weekdays;

  const ReminderDraft({required this.enabled, required this.time, required this.weekdays});

  factory ReminderDraft.of(HabitReminder reminder) =>
      ReminderDraft(enabled: reminder.enabled, time: reminder.time, weekdays: reminder.weekdays);

  HabitReminder forHabit(String habitId) =>
      HabitReminder(habitId: habitId, enabled: enabled, time: time, weekdays: weekdays);

  @override
  bool operator ==(Object other) =>
      other is ReminderDraft && other.enabled == enabled && other.time == time && setEquals(other.weekdays, weekdays);

  @override
  int get hashCode => Object.hash(enabled, time, Object.hashAllUnordered(weekdays));
}
