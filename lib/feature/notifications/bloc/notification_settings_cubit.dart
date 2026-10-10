// The setters are passed straight to Switch.onChanged, which gives a positional bool.
// ignore_for_file: avoid_positional_boolean_parameters
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/feature/notifications/data/notification_repository.dart';
import 'package:go_habit/feature/notifications/domain/models/reminder_settings.dart';
import 'package:go_habit/feature/notifications/notification_service.dart';

@immutable
class NotificationSettingsState {
  final NotificationPreferences preferences;
  final NotificationPermission permission;
  final bool loaded;

  const NotificationSettingsState({
    this.preferences = const NotificationPreferences(),
    this.permission = NotificationPermission.notRequested,
    this.loaded = false,
  });

  /// Reminders can actually appear: the app's switch is on and the system allows it.
  bool get active => preferences.enabled && permission == NotificationPermission.granted;

  NotificationSettingsState copyWith({NotificationPreferences? preferences, NotificationPermission? permission}) =>
      NotificationSettingsState(
        preferences: preferences ?? this.preferences,
        permission: permission ?? this.permission,
        loaded: true,
      );
}

/// App-wide notification preferences and the system permission state. Turning
/// something on asks for permission once, in context; the service reschedules on
/// every saved change.
class NotificationSettingsCubit extends Cubit<NotificationSettingsState> {
  final NotificationRepository _repository;
  final NotificationService _service;
  StreamSubscription<NotificationPreferences>? _subscription;

  NotificationSettingsCubit(this._repository, this._service) : super(const NotificationSettingsState()) {
    _subscription = _repository.watchPreferences().listen((preferences) {
      if (!isClosed) emit(state.copyWith(preferences: preferences));
    });
    unawaited(refreshPermission());
  }

  /// Reads the permission again, e.g. after returning from the system settings.
  Future<void> refreshPermission() async {
    final permission = await _service.permission();
    if (!isClosed) emit(state.copyWith(permission: permission));
  }

  /// Asks for permission if it was never asked; returns the resulting state.
  Future<NotificationPermission> ensurePermission() async {
    final permission = await _service.requestPermission();
    if (!isClosed) emit(state.copyWith(permission: permission));
    return permission;
  }

  Future<void> openSystemSettings() => _service.openSystemSettings();

  Future<void> _save(NotificationPreferences preferences, {bool turnsOn = false}) async {
    emit(state.copyWith(preferences: preferences));
    await _repository.savePreferences(preferences);
    if (turnsOn) await ensurePermission();
  }

  Future<void> setEnabled(bool value) => _save(state.preferences.copyWith(enabled: value), turnsOn: value);

  Future<void> setDailyProgress(bool value) => _save(state.preferences.copyWith(dailyProgress: value), turnsOn: value);

  Future<void> setDailyProgressTime(TimeOfDay time) => _save(state.preferences.copyWith(dailyProgressTime: time));

  Future<void> setStreakRisk(bool value) => _save(state.preferences.copyWith(streakRisk: value), turnsOn: value);

  Future<void> setStreakRiskTime(TimeOfDay time) => _save(state.preferences.copyWith(streakRiskTime: time));

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
