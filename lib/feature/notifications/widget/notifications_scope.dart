import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/feature/initizialization/scopes/app_scope_container.dart';
import 'package:go_habit/feature/notifications/bloc/notification_center_bloc.dart';
import 'package:go_habit/feature/notifications/bloc/notification_settings_cubit.dart';
import 'package:go_habit/feature/notifications/data/notification_repository.dart';
import 'package:yx_scope_flutter/yx_scope_flutter.dart';

/// Notification preferences, permission state and the history, for every screen.
class NotificationsScope extends StatelessWidget {
  final Widget child;

  const NotificationsScope({required this.child, super.key});

  @override
  Widget build(BuildContext context) => ScopeBuilder<AppScopeContainer>.withPlaceholder(
        builder: (context, scope) => RepositoryProvider<NotificationRepository>.value(
          value: scope.notificationRepository.get,
          child: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) =>
                    NotificationSettingsCubit(scope.notificationRepository.get, scope.notificationService.get),
              ),
              BlocProvider(
                create: (_) =>
                    NotificationCenterBloc(scope.notificationRepository.get)..add(const NotificationCenterStarted()),
              ),
            ],
            child: child,
          ),
        ),
      );
}
