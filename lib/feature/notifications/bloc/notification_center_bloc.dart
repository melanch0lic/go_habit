import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/feature/notifications/data/notification_repository.dart';
import 'package:go_habit/feature/notifications/domain/models/app_notification.dart';

sealed class NotificationCenterEvent {
  const NotificationCenterEvent();
}

final class NotificationCenterStarted extends NotificationCenterEvent {
  const NotificationCenterStarted();
}

final class NotificationRead extends NotificationCenterEvent {
  final String id;

  const NotificationRead(this.id);
}

final class NotificationsAllRead extends NotificationCenterEvent {
  const NotificationsAllRead();
}

final class NotificationDeleted extends NotificationCenterEvent {
  final String id;

  const NotificationDeleted(this.id);
}

final class NotificationHistoryCleared extends NotificationCenterEvent {
  const NotificationHistoryCleared();
}

final class _HistoryChanged extends NotificationCenterEvent {
  final List<AppNotification> items;

  const _HistoryChanged(this.items);
}

final class _HistoryFailed extends NotificationCenterEvent {
  const _HistoryFailed();
}

enum NotificationCenterStatus { loading, ready, failure }

@immutable
final class NotificationCenterState {
  final NotificationCenterStatus status;

  /// Newest first.
  final List<AppNotification> items;

  const NotificationCenterState({this.status = NotificationCenterStatus.loading, this.items = const []});

  int get unreadCount => items.where((item) => !item.isRead).length;
}

/// The in-app notification history. Changes are applied to the visible list at once
/// and then persisted; the database stream confirms them.
class NotificationCenterBloc extends Bloc<NotificationCenterEvent, NotificationCenterState> {
  final NotificationRepository _repository;
  final DateTime Function() _now;
  StreamSubscription<List<AppNotification>>? _subscription;

  NotificationCenterBloc(this._repository, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(const NotificationCenterState()) {
    on<NotificationCenterStarted>((event, emit) async {
      await _subscription?.cancel();
      _subscription = _repository.watchHistory().listen(
            (items) => add(_HistoryChanged(items)),
            onError: (Object _) => add(const _HistoryFailed()),
          );
    });
    on<_HistoryChanged>(
        (event, emit) => emit(NotificationCenterState(status: NotificationCenterStatus.ready, items: event.items)));
    on<_HistoryFailed>((event, emit) => emit(NotificationCenterState(
          status: state.items.isEmpty ? NotificationCenterStatus.failure : NotificationCenterStatus.ready,
          items: state.items,
        )));
    on<NotificationRead>((event, emit) async {
      _apply(emit, [
        for (final item in state.items) item.id == event.id && !item.isRead ? _read(item) : item,
      ]);
      await _repository.markRead(event.id);
    });
    on<NotificationsAllRead>((event, emit) async {
      _apply(emit, [for (final item in state.items) item.isRead ? item : _read(item)]);
      await _repository.markAllRead();
    });
    on<NotificationDeleted>((event, emit) async {
      _apply(emit, [
        for (final item in state.items)
          if (item.id != event.id) item
      ]);
      await _repository.deleteFromHistory(event.id);
    });
    on<NotificationHistoryCleared>((event, emit) async {
      _apply(emit, const []);
      await _repository.clearHistory();
    });
  }

  AppNotification _read(AppNotification item) => AppNotification(
        id: item.id,
        category: item.category,
        title: item.title,
        body: item.body,
        habitId: item.habitId,
        createdAt: item.createdAt,
        readAt: _now(),
      );

  void _apply(Emitter<NotificationCenterState> emit, List<AppNotification> items) =>
      emit(NotificationCenterState(status: NotificationCenterStatus.ready, items: items));

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
