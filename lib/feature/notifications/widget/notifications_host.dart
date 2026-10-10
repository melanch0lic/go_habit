import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/feature/notifications/bloc/notification_settings_cubit.dart';
import 'package:go_habit/feature/notifications/notification_service.dart';
import 'package:go_habit/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

/// Connects the notification service to the running app: it passes the language,
/// tells the service when the app returns to the foreground, and opens the target of
/// a tapped notification — also the one that launched the app.
class NotificationsHost extends StatefulWidget {
  final NotificationService service;
  final GoRouter router;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final Widget child;

  const NotificationsHost({
    required this.service,
    required this.router,
    required this.messengerKey,
    required this.child,
    super.key,
  });

  @override
  State<NotificationsHost> createState() => _NotificationsHostState();
}

class _NotificationsHostState extends State<NotificationsHost> with WidgetsBindingObserver {
  StreamSubscription<NotificationTap>? _taps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _taps = widget.service.taps.listen(_open);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.service.takeLaunchTap() case final tap?) _open(tap);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.service.setLocale(Localizations.localeOf(context).languageCode);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(widget.service.onResume());
    try {
      // The user may have changed the permission in the system settings.
      unawaited(context.read<NotificationSettingsCubit>().refreshPermission());
    } on ProviderNotFoundException {
      // Not provided in this tree.
    }
  }

  /// Opening a reminder only navigates; it never marks the habit as done.
  void _open(NotificationTap tap) {
    if (!mounted) return;
    final habitId = tap.habitId;
    if (habitId == null) {
      widget.router.go(CalendarRoutes.calendar.path);
    } else if (tap.habitExists) {
      widget.router.go(CalendarRoutes.openHabit(habitId, request: '${DateTime.now().microsecondsSinceEpoch}'));
    } else {
      widget.router.go(NotificationsRoutes.notifications.path);
      final message = lookupAppLocalizations(Localizations.localeOf(context)).notifications_habit_missing;
      widget.messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_taps?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
