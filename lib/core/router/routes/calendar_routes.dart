part of '../app_router.dart';

final _calendarRoutes = [
  GoRoute(
    parentNavigatorKey: _calendarRoutesNavigatorKey,
    path: CalendarRoutes.calendar.path,
    name: CalendarRoutes.calendar.name,
    // `open` (a habit id) and `request` come from a tapped reminder.
    builder: (_, state) => HabitsPage(
      key: state.pageKey,
      openHabitId: state.uri.queryParameters['open'],
      openRequest: state.uri.queryParameters['request'],
    ),
  ),
];
