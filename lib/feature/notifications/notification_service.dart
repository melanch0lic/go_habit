import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/habit_stats/domain/repositories/habit_stats_repository.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/repositories/habit_repository.dart';
import 'package:go_habit/feature/notifications/data/notification_gateway.dart';
import 'package:go_habit/feature/notifications/data/notification_repository.dart';
import 'package:go_habit/feature/notifications/domain/models/app_notification.dart';
import 'package:go_habit/feature/notifications/domain/models/reminder_settings.dart';
import 'package:go_habit/feature/notifications/domain/notification_plan.dart';
import 'package:go_habit/l10n/app_localizations.dart';
import 'package:l/l.dart';

/// Where a tapped notification leads.
@immutable
class NotificationTap {
  final NotificationCategory category;

  /// The habit the notification is about, if any.
  final String? habitId;

  /// Whether that habit still exists on this device (it may have been deleted).
  final bool habitExists;

  const NotificationTap({required this.category, this.habitId, this.habitExists = false});
}

/// The one place that talks to the operating system about notifications.
///
/// It keeps the scheduled notifications equal to [planNotifications] for the current
/// habits, completions, reminders, preferences, language and time zone: every change
/// triggers a reconciliation, which cancels what is no longer wanted and schedules
/// what is missing. Reconciliations run one at a time and are idempotent, so bursts
/// of changes never produce duplicates.
///
/// It also records the in-app history, but only for events the app can observe:
/// notifications on screen when the app runs, and notifications the user tapped.
class NotificationService {
  final NotificationGateway _gateway;
  final NotificationRepository _repository;
  final HabitRepository _habits;
  final HabitStatsRepository _stats;
  final DateTime Function() _now;
  final Duration _debounce;

  NotificationService({
    required NotificationGateway gateway,
    required NotificationRepository repository,
    required HabitRepository habits,
    required HabitStatsRepository stats,
    DateTime Function()? now,
    Duration debounce = const Duration(milliseconds: 300),
  })  : _gateway = gateway,
        _repository = repository,
        _habits = habits,
        _stats = stats,
        _now = now ?? DateTime.now,
        _debounce = debounce;

  final _subscriptions = <StreamSubscription<Object?>>[];
  final _taps = StreamController<NotificationTap>.broadcast();
  Timer? _debounceTimer;
  Future<void> _queue = Future.value();
  bool _started = false;

  List<Habit> _habitList = const [];
  Map<String, List<CalendarDay>> _completions = const {};
  Map<String, HabitReminder> _reminders = const {};
  NotificationPreferences _preferences = const NotificationPreferences();
  AppLocalizations _l10n = lookupAppLocalizations(const Locale('ru'));
  String _timeZone = 'UTC';
  NotificationTap? _launchTap;

  /// Taps on notifications while the app runs or returns from the background.
  Stream<NotificationTap> get taps => _taps.stream;

  NotificationPreferences get preferences => _preferences;

  /// The tap that launched the app, delivered once.
  NotificationTap? takeLaunchTap() {
    final tap = _launchTap;
    _launchTap = null;
    return tap;
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await _gateway.initialize(onTap: (payload) => unawaited(_handleTap(payload)));
      _timeZone = await _gateway.refreshTimeZone();
      _habitList = await _habits.getHabits();
      _reminders = await _repository.getReminders();
      _preferences = await _repository.getPreferences();
      final launch = await _gateway.launchPayload();
      if (launch != null) _launchTap = await _recordTap(launch);
    } on Object catch (error, stackTrace) {
      // Reminders stay off; the rest of the app is unaffected.
      l.e('Notifications could not start: $error', stackTrace);
    }
    _subscriptions
      ..add(_habits.watchHabits().listen((habits) {
        _habitList = habits;
        _requestReconcile();
      }))
      ..add(_stats.watchCompletions().listen((completions) {
        final byHabit = <String, List<CalendarDay>>{};
        for (final completion in completions) {
          (byHabit[completion.habitId] ??= []).add(completion.completedOn);
        }
        _completions = byHabit;
        _requestReconcile();
      }))
      ..add(_repository.watchReminders().listen((reminders) {
        _reminders = reminders;
        _requestReconcile();
      }))
      ..add(_repository.watchPreferences().listen((preferences) {
        _preferences = preferences;
        _requestReconcile();
      }));
    await _recordShown();
    _requestReconcile();
  }

  /// The app language changed: notification texts and channel names follow it.
  void setLocale(String languageCode) {
    final next = lookupAppLocalizations(Locale(languageCode == 'en' ? 'en' : 'ru'));
    if (next.localeName == _l10n.localeName) return;
    _l10n = next;
    unawaited(_gateway.createChannels(_channelNames()).catchError((Object _) {}));
    _requestReconcile();
  }

  /// The app came to the foreground: a new day, a new time zone or a permission
  /// changed in the system settings may need a new plan; notifications on screen go
  /// into the history.
  Future<void> onResume() async {
    try {
      _timeZone = await _gateway.refreshTimeZone();
    } on Object {
      // Keep the previous zone.
    }
    await _recordShown();
    _requestReconcile();
  }

  Future<NotificationPermission> permission() => _gateway.permission(requestedBefore: _preferences.permissionRequested);

  /// Shows the system prompt once; afterwards only the system settings can grant it.
  Future<NotificationPermission> requestPermission() async {
    final current = await permission();
    if (current != NotificationPermission.notRequested) return current;
    await _gateway.requestPermission();
    await _repository.savePreferences(_preferences = _preferences.copyWith(permissionRequested: true));
    _requestReconcile();
    return permission();
  }

  Future<void> openSystemSettings() => _gateway.openSystemSettings();

  void _requestReconcile() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => unawaited(reconcile()));
  }

  /// Makes the scheduled notifications match the plan. Safe to call any time; calls
  /// run one after another.
  Future<void> reconcile() => _queue = _queue.then((_) => _reconcile()).catchError((Object error, StackTrace stack) {
        l.e('Notification reconciliation failed', stack);
      });

  Future<void> _reconcile() async {
    final granted = await permission() == NotificationPermission.granted;
    // Without permission nothing would be shown: schedule nothing rather than pretend.
    final plan = granted
        ? planNotifications(
            now: _now(),
            preferences: _preferences,
            habits: _habitList,
            reminders: _reminders,
            completions: _completions,
            l10n: _l10n,
            timeZone: _timeZone,
          )
        : const <PlannedNotification>[];
    final wanted = {for (final notification in plan) notification.id: notification};
    final pending = {
      for (final notification in await _gateway.pending())
        if (NotificationIds.isManaged(notification.id)) notification.id: notification.payload,
    };

    for (final MapEntry(key: id, value: payload) in pending.entries) {
      if (wanted[id]?.payload != payload) await _gateway.cancel(id);
    }
    for (final notification in plan) {
      if (pending[notification.id] == notification.payload) continue;
      try {
        await _gateway.schedule(notification);
      } on Object catch (error, stack) {
        // One failure (e.g. a platform limit) must not stop the others.
        l.e('Could not schedule notification ${notification.id}: $error', stack);
      }
    }

    // Reminders of habits deleted elsewhere are not needed any more.
    final ids = _habitList.map((habit) => habit.id).toSet();
    if (_reminders.keys.any((id) => !ids.contains(id)) && _habitList.isNotEmpty) {
      await _repository.pruneReminders(ids);
    }
  }

  /// The history id of one occurrence of a notification: the same occurrence seen on
  /// screen and then tapped stays one record.
  static String historyId(NotificationPayload payload, DateTime occurredAt) =>
      '${payload.category.wire}:${payload.habitId ?? '-'}:${occurredAt.toIso8601String()}';

  Future<void> _recordShown() async {
    try {
      final now = _now();
      for (final shown in await _gateway.active()) {
        final payload = NotificationPayload.tryParse(shown.payload);
        if (payload == null) continue;
        final at = payload.occurredAt(now);
        await _repository.addToHistory(AppNotification(
          id: historyId(payload, at),
          category: payload.category,
          title: payload.title,
          body: payload.body,
          habitId: payload.habitId,
          createdAt: at,
        ));
      }
    } on Object catch (error, stack) {
      l.e('Could not read notifications on screen: $error', stack);
    }
  }

  /// Records a tapped notification as read history and works out where it leads.
  /// Opening a reminder never marks the habit as done.
  Future<NotificationTap?> _recordTap(String? rawPayload) async {
    final payload = NotificationPayload.tryParse(rawPayload);
    if (payload == null) return null;
    final now = _now();
    final at = payload.occurredAt(now);
    final id = historyId(payload, at);
    final added = await _repository.addToHistory(AppNotification(
      id: id,
      category: payload.category,
      title: payload.title,
      body: payload.body,
      habitId: payload.habitId,
      createdAt: at,
      readAt: now,
    ));
    if (!added) await _repository.markRead(id);
    final habitId = payload.habitId;
    final habits = await _habits.getHabits();
    return NotificationTap(
      category: payload.category,
      habitId: habitId,
      habitExists: habitId != null && habits.any((habit) => habit.id == habitId),
    );
  }

  Future<void> _handleTap(String? payload) async {
    try {
      final tap = await _recordTap(payload);
      if (tap != null) _taps.add(tap);
    } on Object catch (error, stack) {
      l.e('Could not handle a notification tap: $error', stack);
    }
  }

  ChannelNames _channelNames() => (
        habits: _l10n.notifications_channel_habits,
        habitsDescription: _l10n.notifications_channel_habits_description,
        progress: _l10n.notifications_channel_progress,
        progressDescription: _l10n.notifications_channel_progress_description,
      );

  Future<void> dispose() async {
    _debounceTimer?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _taps.close();
  }
}
