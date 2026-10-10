import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/feature/habits/view/components/modal_bottom_sheet.dart';
import 'package:go_habit/feature/notifications/bloc/notification_settings_cubit.dart';
import 'package:go_habit/feature/notifications/domain/models/reminder_settings.dart';
import 'package:go_habit/feature/notifications/notification_service.dart';
import 'package:go_habit/feature/notifications/view/notification_settings_screen.dart';
import 'package:go_habit/l10n/app_localizations.dart';
import 'package:go_habit/l10n/app_localizations_ru.dart';

import '../habits/habits_fakes.dart';
import 'notification_fakes.dart';

final l10n = AppLocalizationsRu();

class _Harness {
  final gateway = FakeGateway();
  final FakeNotificationRepository repository;
  final habits = FakeHabitRepository();
  final stats = FakeStatsRepository();
  late final service = NotificationService(gateway: gateway, repository: repository, habits: habits, stats: stats);
  late final cubit = NotificationSettingsCubit(repository, service);

  _Harness({NotificationPreferences preferences = const NotificationPreferences()})
      : repository = FakeNotificationRepository(preferences: preferences);

  Widget build(Widget home) => BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          theme: AppTheme.defaultTheme.lightTheme,
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: home,
        ),
      );

  void dispose() {
    cubit.close();
    service.dispose();
    repository.dispose();
    habits.dispose();
    stats.dispose();
  }
}

void main() {
  group('settings screen', () {
    Future<_Harness> open(WidgetTester tester,
        {NotificationPermission permission = NotificationPermission.granted,
        NotificationPreferences preferences = const NotificationPreferences()}) async {
      final harness = _Harness(preferences: preferences);
      harness.gateway.systemPermission = permission;
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.build(const NotificationSettingsScreen()));
      await tester.pumpAndSettle();
      return harness;
    }

    testWidgets('permission granted: no banner; the master switch is on by default', (tester) async {
      await open(tester);
      expect(find.text(l10n.notifications_permission_denied), findsNothing);
      expect(
          tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, l10n.notifications_master)).value, isTrue);
    });

    testWidgets('denied permission is explained, with a way to the system settings', (tester) async {
      final harness = await open(tester, permission: NotificationPermission.denied);
      expect(find.text(l10n.notifications_permission_denied), findsOneWidget);
      await tester.tap(find.text(l10n.notifications_open_settings));
      await tester.pumpAndSettle();
      expect(harness.gateway.log, contains('settings'));
    });

    testWidgets('not asked yet: allowing shows the system prompt once', (tester) async {
      final harness = await open(tester, permission: NotificationPermission.notRequested);
      await tester.tap(find.text(l10n.notifications_allow));
      await tester.pumpAndSettle();
      expect(harness.gateway.log.where((e) => e == 'request'), hasLength(1));
      expect(find.text(l10n.notifications_permission_request), findsNothing, reason: 'granted now');
      // Let the rescheduling the grant triggered finish.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('turning the master switch off disables the other reminders and is saved', (tester) async {
      final harness = await open(tester);
      await tester.tap(find.text(l10n.notifications_master));
      await tester.pumpAndSettle();
      expect((await harness.repository.getPreferences()).enabled, isFalse);
      expect(
        tester
            .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, l10n.notifications_progress_setting))
            .onChanged,
        isNull,
      );
    });

    testWidgets('the daily progress reminder shows and saves its time', (tester) async {
      final harness = await open(tester);
      await tester.tap(find.text(l10n.notifications_progress_setting));
      await tester.pumpAndSettle();
      expect((await harness.repository.getPreferences()).dailyProgress, isTrue);
      expect(find.text(l10n.notifications_time('20:00')), findsOneWidget);
    });
  });

  group('habit form reminder', () {
    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('a weekly target needs explicit reminder days; the draft carries the reminder', (tester) async {
      final harness = _Harness();
      harness.gateway.systemPermission = NotificationPermission.notRequested;
      addTearDown(harness.dispose);
      HabitDraft? draft;
      await tester.pumpWidget(harness.build(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => draft = await HabitFormSheet.show(context, categories: [
              // One category, so the form can be saved.
              ...await FakeCategoryRepository().getHabitCategories(),
            ]),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, l10n.habits_name_label), 'Бег');
      await tapVisible(tester, find.widgetWithText(ChoiceChip, l10n.habits_schedule_option_weekly));
      await tapVisible(tester, find.text(l10n.habits_reminder_toggle));
      expect(find.text(l10n.habits_reminder_weekly_hint), findsOneWidget);

      await tester.tap(find.text(l10n.social_save));
      await tester.pumpAndSettle();
      expect(find.text(l10n.habits_reminder_days_required), findsOneWidget, reason: 'no fixed days to assume');
      expect(draft, isNull);

      await tapVisible(tester, find.bySemanticsLabel(l10n.habits_weekday_2).last);
      await tester.tap(find.text(l10n.social_save));
      await tester.pumpAndSettle();
      expect(draft!.schedule, HabitSchedule.weeklyTarget(3));
      expect(draft!.reminder, const ReminderDraft(enabled: true, time: TimeOfDay(hour: 9, minute: 0), weekdays: {2}));
      expect(harness.gateway.log, contains('request'), reason: 'permission asked when the reminder was turned on');
    });

    testWidgets('a daily habit starts with every day; no reminder means no draft reminder', (tester) async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      HabitDraft? draft;
      await tester.pumpWidget(harness.build(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => draft = await HabitFormSheet.show(
              context,
              categories: await FakeCategoryRepository().getHabitCategories(),
            ),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, l10n.habits_name_label), 'Вода');
      await tester.tap(find.text(l10n.social_save));
      await tester.pumpAndSettle();
      expect(draft!.reminder, isNull);
    });

    testWidgets('editing keeps the stored reminder and shows that notifications are off', (tester) async {
      final harness = _Harness(preferences: const NotificationPreferences(enabled: false));
      addTearDown(harness.dispose);
      const stored = ReminderDraft(enabled: true, time: TimeOfDay(hour: 7, minute: 15), weekdays: {1, 5});
      HabitDraft? draft;
      await tester.pumpWidget(harness.build(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => draft = await HabitFormSheet.show(
              context,
              categories: await FakeCategoryRepository().getHabitCategories(),
              habit: habit('a', title: 'Зал'),
              reminder: stored,
            ),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l10n.habits_reminder_toggle));
      await tester.pumpAndSettle();
      // Russian formats the time as H:mm; the switch summarises time and days.
      expect(find.text('7:15'), findsOneWidget);
      expect(find.text('7:15 · Пн, Пт'), findsOneWidget);
      expect(find.text(l10n.habits_reminder_off_hint), findsOneWidget);
      await tester.tap(find.text(l10n.social_save));
      await tester.pumpAndSettle();
      expect(draft!.reminder, stored);
    });

    testWidgets('a failed save scrolls to the reminder days, and the sheet stays below the status bar', (tester) async {
      tester.view
        ..physicalSize = const Size(390, 700)
        ..devicePixelRatio = 1
        ..padding = const FakeViewPadding(top: 47);
      addTearDown(tester.view.reset);
      final harness = _Harness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.build(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => HabitFormSheet.show(
              context,
              categories: await FakeCategoryRepository().getHabitCategories(),
              habit: habit('a', title: 'Бег', schedule: HabitSchedule.weeklyTarget(3)),
            ),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text(l10n.habits_edit_title)).dy, greaterThanOrEqualTo(47),
          reason: 'the header is not under the status bar');

      await tapVisible(tester, find.text(l10n.habits_reminder_toggle));
      // Save is pinned at the top of the sheet, reachable from anywhere in the form.
      await tester.tap(find.text(l10n.social_save));
      await tester.pumpAndSettle();

      final error = find.text(l10n.habits_reminder_days_required);
      expect(error, findsOneWidget);
      final screen = Offset.zero & tester.view.physicalSize;
      expect(screen.contains(tester.getCenter(error)), isTrue, reason: 'the reason is scrolled into view');
      expect(find.text(l10n.habits_edit_title), findsOneWidget, reason: 'still editing');
    });
  });
}
