import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/feature/habits/bloc/habits_bloc.dart';
import 'package:go_habit/feature/notifications/bloc/notification_center_bloc.dart';
import 'package:go_habit/feature/notifications/domain/models/app_notification.dart';
import 'package:go_habit/feature/notifications/view/notifications_screen.dart';
import 'package:go_habit/l10n/app_localizations.dart';
import 'package:go_habit/l10n/app_localizations_ru.dart';
import 'package:go_router/go_router.dart';

import '../habits/habits_fakes.dart';
import 'notification_fakes.dart';

final l10n = AppLocalizationsRu();
final now = DateTime(2026, 10, 9, 12);

AppNotification item(
  String id, {
  required DateTime at,
  bool read = false,
  String? habitId = 'a',
  String title = 'Время для привычки',
  String body = '📚 Чтение — уделите этому несколько минут сегодня.',
  NotificationCategory category = NotificationCategory.habitReminder,
}) =>
    AppNotification(
      id: id,
      category: category,
      title: title,
      body: body,
      habitId: habitId,
      createdAt: at,
      readAt: read ? at : null,
    );

class _Harness {
  final FakeNotificationRepository repository;
  final habits = FakeHabitRepository([habit('a', title: 'Чтение')]);
  late final HabitsBloc habitsBloc = HabitsBloc(habits);
  late final NotificationCenterBloc bloc;
  final visited = <Uri>[];
  late final GoRouter router;

  _Harness(List<AppNotification> history, {bool start = true})
      : repository = FakeNotificationRepository(history: history) {
    bloc = NotificationCenterBloc(repository, now: () => now);
    if (start) bloc.add(const NotificationCenterStarted());
    router = GoRouter(
      initialLocation: NotificationsRoutes.notifications.path,
      routes: [
        GoRoute(
          path: NotificationsRoutes.notifications.path,
          builder: (_, __) => NotificationsScreen(now: () => now),
        ),
        GoRoute(
          path: CalendarRoutes.calendar.path,
          builder: (_, state) {
            visited.add(state.uri);
            return const Scaffold(body: Text('habits'));
          },
        ),
        GoRoute(
          path: ProfileRoutes.notificationSettings.path,
          builder: (_, __) => const Scaffold(body: Text('settings')),
        ),
      ],
    );
  }

  Widget build({bool dark = false}) => MultiBlocProvider(
        providers: [BlocProvider.value(value: bloc), BlocProvider.value(value: habitsBloc)],
        child: MaterialApp.router(
          routerConfig: router,
          theme: dark ? AppTheme.defaultTheme.darkTheme : AppTheme.defaultTheme.lightTheme,
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      );

  /// Closing is not awaited: it would never complete inside the fake async zone.
  void dispose() {
    bloc.close();
    habitsBloc.close();
    router.dispose();
    repository.dispose();
    habits.dispose();
  }
}

Future<_Harness> _pump(WidgetTester tester, List<AppNotification> history,
    {bool start = true, bool dark = false}) async {
  final harness = _Harness(history, start: start);
  addTearDown(harness.dispose);
  await tester.pumpWidget(harness.build(dark: dark));
  // A spinner never settles.
  if (start) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return harness;
}

void main() {
  testWidgets('loading until the history arrives', (tester) async {
    await _pump(tester, const [], start: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('an empty history explains itself and leads to the settings', (tester) async {
    final harness = await _pump(tester, const []);
    expect(find.text(l10n.notifications_empty), findsOneWidget);
    expect(find.text(l10n.notifications_empty_hint), findsOneWidget);
    await tester.tap(find.text(l10n.notifications_settings_title).last);
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);
    expect(harness.repository.history, isEmpty, reason: 'no invented records');
  });

  testWidgets('records are grouped by day; unread ones are marked without relying on color', (tester) async {
    await _pump(tester, [
      item('today', at: now.subtract(const Duration(minutes: 5))),
      item('yesterday', at: DateTime(2026, 10, 8, 21), read: true, category: NotificationCategory.dailyProgress),
      item('earlier', at: DateTime(2026, 10, 1, 9), read: true),
    ]);
    for (final header in [l10n.notifications_today, l10n.notifications_yesterday, l10n.notifications_earlier]) {
      expect(find.text(header), findsOneWidget);
    }
    expect(find.textContaining(l10n.notifications_minutes_ago(5)), findsOneWidget);
    expect(find.textContaining('${l10n.notifications_yesterday}, 21:00'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^${l10n.notifications_unread}')), findsOneWidget);
  });

  testWidgets('tapping a record marks it read and opens its habit', (tester) async {
    final harness = await _pump(tester, [item('n1', at: now.subtract(const Duration(hours: 2)))]);
    await tester.tap(find.text('Время для привычки'));
    await tester.pumpAndSettle();
    expect(harness.visited.single.queryParameters['open'], 'a');
    expect(harness.repository.history.single.isRead, isTrue);
  });

  testWidgets('a record of a deleted habit says so instead of navigating', (tester) async {
    final harness = await _pump(tester, [item('n1', at: now, habitId: 'gone')]);
    await tester.tap(find.text('Время для привычки'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.notifications_habit_missing), findsOneWidget);
    expect(harness.visited, isEmpty);
  });

  testWidgets('mark all as read, delete one by swiping, clear with confirmation', (tester) async {
    final harness = await _pump(tester, [
      item('a1', at: now.subtract(const Duration(minutes: 1)), title: 'Первое'),
      item('a2', at: now.subtract(const Duration(minutes: 2)), title: 'Второе'),
    ]);
    await tester.tap(find.byTooltip(l10n.notifications_mark_all_read));
    await tester.pumpAndSettle();
    expect(harness.repository.history.every((n) => n.isRead), isTrue);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.done_all)).onPressed, isNull,
        reason: 'nothing left to mark');

    await tester.drag(find.text('Первое'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(harness.repository.history.map((n) => n.id), ['a2']);

    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.notifications_clear_all));
    await tester.pumpAndSettle();
    expect(find.text(l10n.notifications_clear_message), findsOneWidget);
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(harness.repository.history, hasLength(1), reason: 'cancel keeps the history');

    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.notifications_clear_all));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.notifications_clear_confirm));
    await tester.pumpAndSettle();
    expect(harness.repository.history, isEmpty);
    expect(find.text(l10n.notifications_empty), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('long texts and large type fit a small phone (${dark ? 'dark' : 'light'})', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 568)
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(
        tester,
        [
          for (var i = 0; i < 8; i++)
            item(
              'n$i',
              at: now.subtract(Duration(hours: i * 7)),
              read: i.isEven,
              title: 'Очень длинный заголовок уведомления, который не помещается в одну строку $i',
              body: 'Очень длинный текст уведомления, который занимает несколько строк и аккуратно обрезается $i',
            ),
        ],
        dark: dark,
      );
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
