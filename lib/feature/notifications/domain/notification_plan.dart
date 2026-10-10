import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/habit_stats/domain/streak.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/notifications/domain/models/app_notification.dart';
import 'package:go_habit/feature/notifications/domain/models/reminder_settings.dart';
import 'package:go_habit/l10n/app_localizations.dart';

/// How a planned notification repeats.
enum NotificationRepeat {
  /// Every day at [PlannedNotification.time].
  daily,

  /// Every week on [PlannedNotification.weekday] at [PlannedNotification.time].
  weekly,

  /// Once, on [PlannedNotification.date] at [PlannedNotification.time].
  once,
}

/// A notification the app wants the operating system to have scheduled. The
/// [payload] describes it completely, so comparing payloads tells whether a pending
/// notification is still the wanted one.
@immutable
class PlannedNotification {
  final int id;
  final NotificationCategory category;
  final String title;
  final String body;
  final String? habitId;
  final NotificationRepeat repeat;
  final TimeOfDay time;
  final int? weekday;
  final CalendarDay? date;

  /// The time zone the time is meant in; part of the payload, so a time zone change
  /// reschedules everything.
  final String timeZone;

  const PlannedNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.repeat,
    required this.time,
    required this.timeZone,
    this.habitId,
    this.weekday,
    this.date,
  });

  String get payload => jsonEncode(toPayload());

  Map<String, Object?> toPayload() => {
        'c': category.wire,
        if (habitId != null) 'h': habitId,
        'r': repeat.name,
        't': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        if (weekday != null) 'w': weekday,
        if (date != null) 'd': date!.toIsoString(),
        'z': timeZone,
        'ti': title,
        'b': body,
      };

  @override
  String toString() => 'PlannedNotification($id, ${category.wire}, ${repeat.name}, $payload)';
}

/// What a notification payload says, as read back from a tap or a notification on
/// screen. Tolerates payloads of older versions and missing fields.
@immutable
class NotificationPayload {
  final NotificationCategory category;
  final String? habitId;
  final NotificationRepeat? repeat;
  final TimeOfDay? time;
  final CalendarDay? date;
  final String title;
  final String body;

  const NotificationPayload({
    required this.category,
    required this.title,
    required this.body,
    this.habitId,
    this.repeat,
    this.time,
    this.date,
  });

  static NotificationPayload? tryParse(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final json = jsonDecode(payload);
      if (json is! Map) return null;
      final time = (json['t'] as String?)?.split(':');
      final date = json['d'] as String?;
      return NotificationPayload(
        category: NotificationCategory.parse(json['c'] as String?),
        habitId: json['h'] as String?,
        repeat: NotificationRepeat.values.where((r) => r.name == json['r']).firstOrNull,
        time: time == null || time.length != 2
            ? null
            : TimeOfDay(hour: int.tryParse(time[0]) ?? 0, minute: int.tryParse(time[1]) ?? 0),
        date: date == null ? null : CalendarDay.parse(date),
        title: json['ti'] as String? ?? '',
        body: json['b'] as String? ?? '',
      );
    } on FormatException {
      return null;
    }
  }

  /// When this notification most recently fired at or before [now]: its date for a
  /// one-off; today's (or yesterday's) occurrence for a repeating one.
  DateTime occurredAt(DateTime now) {
    final time = this.time;
    if (time == null) return now;
    final date = this.date;
    if (date != null) return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final today = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return today.isAfter(now) ? today.subtract(const Duration(days: 1)) : today;
  }
}

/// Notification ids. Each kind owns a range, and a habit's ids are derived from its
/// id, so the same reminder always gets the same notification id.
abstract final class NotificationIds {
  /// Daily progress reminders for today and the following days (offset 0–6).
  static const dailyProgressBase = 100;
  static const streakRisk = 200;

  /// Habit reminders: base + slot * 8 + (0 every day, 1–7 weekday).
  static const habitBase = 1000;
  static const _habitSlots = 1 << 20;

  /// Whether [id] belongs to a notification this app manages.
  static bool isManaged(int id) => id >= dailyProgressBase;

  /// FNV-1a of the habit id, folded into the slot range.
  static int habitSlot(String habitId) {
    var hash = 0x811c9dc5;
    for (final unit in habitId.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash % _habitSlots;
  }

  /// Slots for [habitIds]; a collision moves the later id (in sorted order) to the next
  /// free slot, so the result is deterministic.
  static Map<String, int> habitSlots(Iterable<String> habitIds) {
    final used = <int>{};
    return {
      for (final id in habitIds.toList()..sort())
        id: () {
          var slot = habitSlot(id);
          while (!used.add(slot)) {
            slot = (slot + 1) % _habitSlots;
          }
          return slot;
        }(),
    };
  }

  static int habit(int slot, {int? weekday}) => habitBase + slot * 8 + (weekday ?? 0);
}

/// iOS keeps at most 64 pending notifications per app; a few are left for the system.
const maxPendingNotifications = 60;

/// How many days ahead one-off daily progress reminders are planned. They are
/// replanned whenever the app runs, habits change or completions change.
const dailyProgressHorizonDays = 7;

/// Every notification the app should have scheduled right now. Pure: the same input
/// always gives the same plan, so applying it repeatedly never duplicates anything.
///
/// - Habit reminders repeat (daily, or weekly per chosen day) for active habits whose
///   reminder is on.
/// - The daily progress reminder is a one-off per day for the next
///   [dailyProgressHorizonDays] days, only on days with something due; today's is
///   skipped once its time has passed or nothing is left to do today.
/// - The streak warning is a one-off for today, only while an unfinished habit's
///   streak (per [computeStreak]) would end if today passes without it.
/// - Nothing is planned while the master switch is off.
List<PlannedNotification> planNotifications({
  required DateTime now,
  required NotificationPreferences preferences,
  required List<Habit> habits,
  required Map<String, HabitReminder> reminders,
  required Map<String, List<CalendarDay>> completions,
  required AppLocalizations l10n,
  required String timeZone,
}) {
  if (!preferences.enabled) return const [];
  final today = CalendarDay.fromDateTime(now);
  final active = habits.where((habit) => habit.isActive).toList();
  final plan = <PlannedNotification>[];

  bool passedToday(TimeOfDay time) => time.hour * 60 + time.minute <= now.hour * 60 + now.minute;
  bool doneOn(Habit habit, CalendarDay day) => completions[habit.id]?.contains(day) ?? false;

  // Streak warning: highest priority, at most one.
  if (preferences.streakRisk && !passedToday(preferences.streakRiskTime)) {
    final atRisk = active.where((habit) => streakEndsToday(habit, completions[habit.id] ?? const [], today)).toList();
    if (atRisk.isNotEmpty) {
      plan.add(PlannedNotification(
        id: NotificationIds.streakRisk,
        category: NotificationCategory.streakRisk,
        title: l10n.notifications_streak_title,
        body: atRisk.length == 1
            ? l10n.notifications_streak_body_one(atRisk.single.title)
            : l10n.notifications_streak_body_many(atRisk.length),
        habitId: atRisk.length == 1 ? atRisk.single.id : null,
        repeat: NotificationRepeat.once,
        time: preferences.streakRiskTime,
        date: today,
        timeZone: timeZone,
      ));
    }
  }

  // Today's progress reminder, if something is still left.
  final progress = <PlannedNotification>[];
  if (preferences.dailyProgress) {
    for (var offset = 0; offset < dailyProgressHorizonDays; offset++) {
      final day = today.addDays(offset);
      final due = active.where((habit) => habit.schedule.isDueOn(day)).toList();
      if (due.isEmpty) continue;
      final String body;
      if (offset == 0) {
        if (passedToday(preferences.dailyProgressTime)) continue;
        final remaining = due.where((habit) => !doneOn(habit, day)).length;
        if (remaining == 0) continue;
        body = l10n.notifications_progress_body(remaining);
      } else {
        // Later days are not known yet: a general invitation, refreshed every day.
        body = l10n.notifications_progress_body_general;
      }
      progress.add(PlannedNotification(
        id: NotificationIds.dailyProgressBase + offset,
        category: NotificationCategory.dailyProgress,
        title: l10n.notifications_progress_title,
        body: body,
        repeat: NotificationRepeat.once,
        time: preferences.dailyProgressTime,
        date: day,
        timeZone: timeZone,
      ));
    }
  }
  if (progress.isNotEmpty && progress.first.date == today) plan.add(progress.removeAt(0));

  // Habit reminders.
  final withReminder = active.where((habit) => reminders[habit.id]?.enabled ?? false).toList();
  final slots = NotificationIds.habitSlots(withReminder.map((habit) => habit.id));
  for (final habit in withReminder..sort((a, b) => a.id.compareTo(b.id))) {
    final reminder = reminders[habit.id]!;
    final slot = slots[habit.id]!;
    final name = [if (habit.icon != null && habit.icon!.isNotEmpty) habit.icon, habit.title].join(' ');
    PlannedNotification planned({int? weekday}) => PlannedNotification(
          id: NotificationIds.habit(slot, weekday: weekday),
          category: NotificationCategory.habitReminder,
          title: l10n.notifications_habit_title,
          body: l10n.notifications_habit_body(name),
          habitId: habit.id,
          repeat: weekday == null ? NotificationRepeat.daily : NotificationRepeat.weekly,
          time: reminder.time,
          weekday: weekday,
          timeZone: timeZone,
        );
    if (reminder.everyDay) {
      plan.add(planned());
    } else {
      plan.addAll([for (final day in reminder.weekdays.toList()..sort()) planned(weekday: day)]);
    }
  }

  // Later progress reminders fill whatever room is left.
  plan.addAll(progress);
  return plan.length > maxPendingNotifications ? plan.sublist(0, maxPendingNotifications) : plan;
}

/// Whether [habit]'s current streak ends if [today] passes without marking it: the
/// streak per [computeStreak] is positive today and would be shorter tomorrow. Uses
/// the one streak implementation, so it never disagrees with what the app shows.
bool streakEndsToday(Habit habit, List<CalendarDay> completedDays, CalendarDay today) {
  if (!habit.isActive) return false;
  int streakOn(CalendarDay day) => computeStreak(
        schedule: habit.schedule,
        completedDays: completedDays,
        today: day,
        resetOn: habit.streakResetOn,
      ).count;
  final current = streakOn(today);
  return current > 0 && streakOn(today.addDays(1)) < current;
}
