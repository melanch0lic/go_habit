import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/feature/categories/domain/models/habit_category.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/feature/habits/view/components/modal_bottom_sheet.dart';
import 'package:go_habit/feature/notifications/domain/models/reminder_settings.dart';
import 'package:go_habit/l10n/app_localizations.dart';
import 'package:go_habit/l10n/app_localizations_ru.dart';

import 'habits_fakes.dart';

final l10n = AppLocalizationsRu();
final _categories = [
  HabitCategory(id: 'health', name: 'Здоровье', color: '#FF6B6B'),
  HabitCategory(id: 'education', name: 'Обучение', color: '#FB8C00'),
  HabitCategory(id: 'sport', name: 'Спорт', color: '#4ECDC4'),
];

/// Opens the form from a button and records how it closed.
class _Host {
  HabitDraft? draft;
  bool closed = false;

  Widget build({bool dark = false, Habit? habit, ReminderDraft? reminder, TargetPlatform? platform}) => MaterialApp(
        theme: (dark ? AppTheme.defaultTheme.darkTheme : AppTheme.defaultTheme.lightTheme).copyWith(platform: platform),
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  draft = await HabitFormSheet.show(context, categories: _categories, habit: habit, reminder: reminder);
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
}

Future<_Host> _open(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  bool dark = false,
  Habit? habit,
  ReminderDraft? reminder,
  TargetPlatform? platform,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  final host = _Host();
  await tester.pumpWidget(host.build(dark: dark, habit: habit, reminder: reminder, platform: platform));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return host;
}

Finder get _form => find.byType(CustomScrollView);
bool _onScreen(WidgetTester tester, Finder finder) =>
    (Offset.zero & tester.view.physicalSize).contains(tester.getCenter(finder));

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Drags the sheet down by its pinned header, like a downward swipe.
Future<void> _swipeDown(WidgetTester tester) async {
  await tester.fling(
      find.text(l10n.habits_new_title).evaluate().isEmpty
          ? find.text(l10n.habits_edit_title)
          : find.text(l10n.habits_new_title),
      const Offset(0, 600),
      1500);
  await tester.pumpAndSettle();
}

void main() {
  group('presentation', () {
    testWidgets('the first screen shows the title, name, schedule and reminder status', (tester) async {
      await _open(tester);
      for (final finder in [
        find.text(l10n.habits_new_title),
        find.widgetWithText(TextFormField, l10n.habits_name_label),
        find.widgetWithText(ChoiceChip, l10n.habits_schedule_option_daily),
        find.text(l10n.habits_reminder_toggle),
        find.text(l10n.habits_reminder_off),
      ]) {
        expect(_onScreen(tester, finder), isTrue, reason: '$finder without scrolling');
      }
      expect(tester.getTopLeft(find.text(l10n.habits_new_title)).dy, greaterThan(47), reason: 'below the status bar');
      expect(tester.testTextInput.isVisible, isFalse, reason: 'no keyboard covering the form on open');
    });

    testWidgets("a filled name's floating label stays clear of the pinned header; description sits under it",
        (tester) async {
      await _open(tester);
      await tester.enterText(find.widgetWithText(TextFormField, l10n.habits_name_label), 'Read books');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      // The bottom of the pinned header's background, not just of its buttons.
      final header =
          find.ancestor(of: find.widgetWithText(FilledButton, l10n.social_save), matching: find.byType(ColoredBox));
      final headerBottom = tester.getBottomLeft(header.first).dy;
      final label = find.descendant(
        of: find.widgetWithText(TextFormField, 'Read books'),
        matching: find.text(l10n.habits_name_label),
      );
      expect(tester.getTopLeft(label).dy, greaterThanOrEqualTo(headerBottom), reason: 'not cut by the header');

      final name = tester.getRect(find.widgetWithText(TextFormField, 'Read books'));
      final description = tester.getRect(find.widgetWithText(TextFormField, l10n.habits_description_label));
      expect(description.top, greaterThan(name.bottom));
      expect(description.left, name.left, reason: 'aligned under the name');
    });

    testWidgets('a downward swipe closes an unchanged form without saving', (tester) async {
      final host = await _open(tester);
      await _swipeDown(tester);
      expect(host.closed, isTrue);
      expect(host.draft, isNull);
    });

    testWidgets('a swipe on a changed form asks first; keeping the changes brings the sheet back', (tester) async {
      final host = await _open(tester);
      await tester.enterText(find.widgetWithText(TextFormField, l10n.habits_name_label), 'Бег');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await _swipeDown(tester);
      expect(find.text(l10n.habits_discard_title), findsOneWidget);

      await tester.tap(find.text(l10n.habits_keep_editing));
      await tester.pumpAndSettle();
      expect(host.closed, isFalse);
      expect(_onScreen(tester, find.text(l10n.habits_new_title)), isTrue, reason: 'the sheet is back');
      expect(find.text('Бег'), findsOneWidget, reason: 'nothing was lost');

      await _swipeDown(tester);
      await tester.tap(find.text(l10n.habits_discard));
      await tester.pumpAndSettle();
      expect((host.closed, host.draft), (true, null));
    });

    testWidgets('scrolling the form up and back does not close it', (tester) async {
      final host = await _open(tester, size: const Size(390, 700));
      await tester.drag(_form, const Offset(0, -500));
      await tester.pumpAndSettle();
      // Back up a little, slowly, while the form is still scrolled.
      await tester.timedDrag(_form, const Offset(0, 100), const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(host.closed, isFalse);
    });

    testWidgets('a tap outside closes an unchanged form and asks about a changed one', (tester) async {
      final host = await _open(tester, size: const Size(390, 1600));
      // The sheet covers most of the screen; the barrier is above it.
      await tester.tapAt(const Offset(195, 60));
      await tester.pumpAndSettle();
      expect(host.closed, isTrue);
    });
  });

  group('reminder', () {
    testWidgets('turning it on reveals the time and days, summarised under the switch', (tester) async {
      await _open(tester);
      expect(find.text(l10n.habits_reminder_time), findsNothing);
      await _tapVisible(tester, find.text(l10n.habits_reminder_toggle));
      expect(find.text(l10n.habits_reminder_time), findsOneWidget);
      expect(find.text('9:00 · ${l10n.habits_reminder_every_day}'), findsOneWidget, reason: 'daily: every day');

      await _tapVisible(tester, find.bySemanticsLabel(l10n.habits_weekday_7).last);
      expect(find.text('9:00 · Пн, Вт, Ср, Чт, Пт, Сб'), findsOneWidget);
    });

    testWidgets('the time picker can be cancelled and confirmed without losing the form', (tester) async {
      await _open(tester);
      await _tapVisible(tester, find.text(l10n.habits_reminder_toggle));
      await _tapVisible(tester, find.text(l10n.habits_reminder_time));
      expect(find.byType(TimePickerDialog), findsOneWidget);
      final material = MaterialLocalizations.of(tester.element(find.byType(TimePickerDialog)));
      Finder inDialog(String text) => find.descendant(of: find.byType(TimePickerDialog), matching: find.text(text));
      await tester.tap(inDialog(material.cancelButtonLabel));
      await tester.pumpAndSettle();
      expect(find.text('9:00'), findsOneWidget);

      // Confirming returns the picked time to the form (unchanged here: the dial is painted,
      // so changing it from a test would depend on its geometry).
      await _tapVisible(tester, find.text(l10n.habits_reminder_time));
      await tester.tap(inDialog(material.okButtonLabel));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(find.text('9:00 · ${l10n.habits_reminder_every_day}'), findsOneWidget);
      expect(find.text(l10n.habits_new_title), findsOneWidget, reason: 'the form stays open with its values');
    });

    testWidgets('on iOS the time is picked with the wheel', (tester) async {
      await _open(tester, platform: TargetPlatform.iOS);
      await _tapVisible(tester, find.text(l10n.habits_reminder_toggle));
      await _tapVisible(tester, find.text(l10n.habits_reminder_time));
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      final material = MaterialLocalizations.of(tester.element(find.byType(CupertinoDatePicker)));
      await tester.tap(find.text(material.okButtonLabel));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsNothing);
      expect(find.text('9:00'), findsOneWidget, reason: 'unchanged time confirmed');
    });

    testWidgets('changing the schedule never overwrites the reminder days', (tester) async {
      final host = await _open(tester);
      await tester.enterText(find.widgetWithText(TextFormField, l10n.habits_name_label), 'Зал');
      await _tapVisible(tester, find.text(l10n.habits_reminder_toggle));
      await _tapVisible(tester, find.widgetWithText(ChoiceChip, l10n.habits_schedule_option_weekdays));
      await _tapVisible(tester, find.bySemanticsLabel(l10n.habits_weekday_1).first);
      expect(find.text('9:00 · ${l10n.habits_reminder_every_day}'), findsOneWidget, reason: 'still every day');

      await tester.tap(find.text(l10n.social_save));
      await tester.pumpAndSettle();
      expect(host.draft!.schedule, HabitSchedule.weekdays({DateTime.monday}));
      expect(host.draft!.reminder!.weekdays, HabitReminder.allDays);
    });

    testWidgets('editing preloads the reminder and keeps it when other fields change', (tester) async {
      const stored = ReminderDraft(enabled: true, time: TimeOfDay(hour: 7, minute: 15), weekdays: {2, 4});
      final host = await _open(
        tester,
        habit: habit('a', title: 'Бег', schedule: HabitSchedule.weeklyTarget(3)),
        reminder: stored,
      );
      expect(find.text('7:15 · Вт, Чт'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Бег'), 'Пробежка');
      await tester.tap(find.text(l10n.social_save));
      await tester.pumpAndSettle();
      expect(host.draft!.title, 'Пробежка');
      expect(host.draft!.reminder, stored);
    });
  });

  group('icon', () {
    testWidgets('the icon next to the name opens the choices', (tester) async {
      final host = await _open(tester);
      await tester.tap(find.bySemanticsLabel(RegExp(l10n.habits_choose_icon)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🏃'));
      await tester.pumpAndSettle();
      expect(find.text('💧'), findsNothing, reason: 'the choices close after picking');
      await tester.enterText(find.widgetWithText(TextFormField, l10n.habits_name_label), 'Бег');
      await tester.tap(find.text(l10n.social_save));
      await tester.pumpAndSettle();
      expect(host.draft!.icon, '🏃');
    });
  });

  for (final dark in [false, true]) {
    testWidgets('small screen with large text fits (${dark ? 'dark' : 'light'})', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _open(tester, size: const Size(320, 568), dark: dark);
      await _tapVisible(tester, find.text(l10n.habits_reminder_toggle));
      expect(tester.takeException(), isNull);
      await tester.drag(_form, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(TextFormField, l10n.habits_description_label), findsOneWidget);
    });
  }
}
