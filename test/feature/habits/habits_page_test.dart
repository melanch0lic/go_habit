import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/categories/bloc/habit_category_bloc.dart';
import 'package:go_habit/feature/habit_stats/bloc/habit_stats_bloc.dart';
import 'package:go_habit/feature/habits/bloc/habits_bloc.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/feature/habits/view/habits_page.dart';
import 'package:go_habit/l10n/app_localizations.dart';
import 'package:go_habit/l10n/app_localizations_ru.dart';

import 'habits_fakes.dart';

final l10n = AppLocalizationsRu();

class _Harness {
  final FakeHabitRepository habits;
  final FakeStatsRepository stats;
  late final HabitsBloc habitsBloc = HabitsBloc(habits, today: () => today);
  late final HabitStatsBloc statsBloc =
      HabitStatsBloc(stats, now: () => today.toDateTime().add(const Duration(hours: 12)))
        ..add(HabitsStatsInitialLoad());
  final categoryBloc = HabitCategoryBloc(FakeCategoryRepository())..add(HabitInitialLoad());

  _Harness({List<Habit> habits = const [], Map<String, List<CalendarDay>> done = const {}})
      : habits = FakeHabitRepository(habits),
        stats = FakeStatsRepository(done);

  Widget build() => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: habitsBloc),
          BlocProvider.value(value: statsBloc),
          BlocProvider.value(value: categoryBloc),
        ],
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
          home: const HabitsPage(),
        ),
      );

  /// Called at the end of each test body: the stats bloc owns a midnight timer that
  /// must be cancelled before the test ends. Not awaited: it would never complete
  /// inside the fake async zone.
  void close() {
    habitsBloc.close();
    statsBloc.close();
    categoryBloc.close();
    habits.dispose();
    stats.dispose();
  }
}

Future<_Harness> _pump(WidgetTester tester,
    {List<Habit> habits = const [], Map<String, List<CalendarDay>> done = const {}}) async {
  final harness = _Harness(habits: habits, done: done);
  await tester.pumpWidget(harness.build());
  await tester.pumpAndSettle();
  return harness;
}

Finder _checkFor(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(InkWell)).first,
      matching: find.bySemanticsLabel(RegExp('${l10n.habit_mark_done}|${l10n.habit_unmark_done}')),
    );

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _scheduleChip(String label) => find.widgetWithText(ChoiceChip, label);

Future<void> _openMenu(WidgetTester tester, String title) async {
  await tester.tap(find.byTooltip(l10n.habits_actions(title)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first use: an empty state with a clear way to add a habit', (tester) async {
    final harness = await _pump(tester);
    expect(find.text(l10n.habits_empty_title), findsOneWidget);

    // FilledButton.icon is a private subclass, so the label is found by text.
    await tester.tap(find.text(l10n.habits_add));
    await tester.pumpAndSettle();
    expect(find.text(l10n.habits_new_title), findsOneWidget);

    // The name is required; the error appears next to the field.
    await tester.tap(find.text(l10n.social_save));
    await tester.pumpAndSettle();
    expect(find.text(l10n.habits_name_required), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, l10n.habits_name_label), 'Пить воду');
    await tester.tap(find.text('📚'));
    await tester.tap(find.text(l10n.social_save));
    await tester.pumpAndSettle();

    final added = harness.habits.habits.single;
    expect((added.title, added.icon, added.description), ('Пить воду', '📚', null));
    expect(find.text('Пить воду'), findsOneWidget);
    expect(find.text(l10n.habits_today_progress(0, 1)), findsOneWidget);
    harness.close();
  });

  testWidgets("today's progress counts only scheduled habits; paused ones are listed apart", (tester) async {
    final harness = await _pump(
      tester,
      habits: [habit('a', title: 'Вода'), habit('b', title: 'Чтение'), habit('p', title: 'Бег', active: false)],
      done: {
        'a': [today],
        'p': [today],
      },
    );
    expect(find.text(l10n.habits_today_progress(1, 2)), findsOneWidget);
    expect(find.text(l10n.habits_section_paused), findsOneWidget);
    expect(_checkFor('Бег'), findsNothing, reason: 'paused habits cannot be completed');
    harness.close();
  });

  testWidgets('completing and undoing with one tap; all done is celebrated', (tester) async {
    final harness = await _pump(tester, habits: [habit('a', title: 'Вода')]);

    await tester.tap(_checkFor('Вода'));
    await tester.pumpAndSettle();
    expect(harness.stats.writes, ['a:true']);
    expect(find.text(l10n.habits_today_all_done), findsOneWidget);

    await tester.tap(_checkFor('Вода'));
    await tester.pumpAndSettle();
    expect(harness.stats.writes, ['a:true', 'a:false']);
    expect(find.text(l10n.habits_today_progress(0, 1)), findsOneWidget);
    harness.close();
  });

  testWidgets('rapid taps while saving produce a single completion', (tester) async {
    final harness = await _pump(tester, habits: [habit('a', title: 'Вода')]);
    harness.stats.gate = Completer<void>();

    await tester.tap(_checkFor('Вода'));
    await tester.pump();
    await tester.tap(_checkFor('Вода'));
    await tester.tap(_checkFor('Вода'));
    await tester.pump();
    expect(find.bySemanticsLabel(l10n.habit_unmark_done), findsOneWidget, reason: 'shown as done at once');

    harness.stats.gate!.complete();
    await tester.pumpAndSettle();
    expect(harness.stats.writes, ['a:true']);
    expect(harness.stats.completions, hasLength(1));
    harness.close();
  });

  testWidgets('a failed completion is explained and the mark is not shown', (tester) async {
    final harness = await _pump(tester, habits: [habit('a', title: 'Вода')]);
    harness.stats.fail = true;

    await tester.tap(_checkFor('Вода'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.habits_error_completion), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.habit_mark_done), findsOneWidget);
    expect(find.text(l10n.habits_today_progress(0, 1)), findsOneWidget);
    harness.close();
  });

  testWidgets('all habits paused: nothing scheduled, not "no habits"', (tester) async {
    final harness = await _pump(tester, habits: [habit('p', title: 'Бег', active: false)]);
    expect(find.text(l10n.habits_nothing_today(1)), findsOneWidget);
    expect(find.text(l10n.habits_empty_title), findsNothing);
    harness.close();
  });

  testWidgets('editing from the card keeps the id and the history', (tester) async {
    final harness = await _pump(tester, habits: [
      habit('a', title: 'Вода')
    ], done: {
      'a': [today.addDays(-1), today],
    });

    await tester.tap(find.text('Вода'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.habits_edit_title), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Вода'), 'Пить воду');
    await tester.tap(find.text('Спорт'));
    await tester.tap(find.text(l10n.social_save));
    await tester.pumpAndSettle();

    final edited = harness.habits.habits.single;
    expect((edited.id, edited.title, edited.categoryId), ('a', 'Пить воду', 'sport'));
    expect(harness.stats.completions, hasLength(2));
    expect(find.text('Пить воду'), findsOneWidget);
    harness.close();
  });

  testWidgets('cancelling an edit with changes asks first and saves nothing', (tester) async {
    final harness = await _pump(tester, habits: [habit('a', title: 'Вода')]);

    await _openMenu(tester, 'Вода');
    await tester.tap(find.text(l10n.habits_edit));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Вода'), 'Что-то другое');
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(find.text(l10n.habits_discard_title), findsOneWidget);

    await tester.tap(find.text(l10n.habits_keep_editing));
    await tester.pumpAndSettle();
    expect(find.text(l10n.habits_edit_title), findsOneWidget, reason: 'still editing');

    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.habits_discard));
    await tester.pumpAndSettle();
    expect(find.text(l10n.habits_edit_title), findsNothing);
    expect(harness.habits.log, isEmpty, reason: 'nothing was written');
    expect(harness.habits.habits.single.title, 'Вода');
    harness.close();
  });

  group('schedules', () {
    testWidgets('a weekly goal is created from the form and shown with its own progress', (tester) async {
      final harness = await _pump(tester, habits: [habit('a', title: 'Вода')]);
      await tester.tap(find.byTooltip(l10n.habits_add));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, l10n.habits_name_label), 'Бег');
      await _tapVisible(tester, _scheduleChip(l10n.habits_schedule_option_weekly));
      await _tapVisible(tester, find.bySemanticsLabel(l10n.habits_schedule_times_per_week(4)));
      expect(find.text(l10n.habits_schedule_weekly_summary(4)), findsOneWidget, reason: 'the summary follows');
      await tester.tap(find.text(l10n.social_save));
      await tester.pumpAndSettle();

      final added = harness.habits.habits.firstWhere((h) => h.title == 'Бег');
      expect(added.schedule, HabitSchedule.weeklyTarget(4));
      expect(find.text(l10n.habits_section_week), findsOneWidget);
      expect(find.text(l10n.habits_week_target_progress(0, 4)), findsOneWidget);
      expect(find.text(l10n.habits_today_progress(0, 1)), findsOneWidget, reason: 'a weekly goal is not due today');
      expect(find.text(l10n.habits_week_goals(0, 1)), findsOneWidget);
      harness.close();
    });

    testWidgets('selected weekdays need at least one day', (tester) async {
      final harness = await _pump(tester);
      await tester.tap(find.text(l10n.habits_add));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, l10n.habits_name_label), 'Зал');
      await _tapVisible(tester, _scheduleChip(l10n.habits_schedule_option_weekdays));
      await tester.tap(find.text(l10n.social_save));
      await tester.pumpAndSettle();
      expect(find.text(l10n.habits_weekdays_required), findsOneWidget);
      expect(harness.habits.habits, isEmpty);

      await _tapVisible(tester, find.bySemanticsLabel(l10n.habits_weekday_1));
      expect(find.text(l10n.habits_weekdays_required), findsNothing);
      await _tapVisible(tester, find.bySemanticsLabel(l10n.habits_weekday_5));
      await tester.tap(find.text(l10n.social_save));
      await tester.pumpAndSettle();
      expect(harness.habits.habits.single.schedule, HabitSchedule.weekdays({DateTime.monday, DateTime.friday}));
      harness.close();
    });

    testWidgets('changing the schedule type asks first; cancel keeps editing and saves nothing', (tester) async {
      final harness = await _pump(tester, habits: [
        habit('a', title: 'Вода')
      ], done: {
        'a': [today.addDays(-1), today],
      });
      await tester.tap(find.text('Вода'));
      await tester.pumpAndSettle();
      await _tapVisible(tester, _scheduleChip(l10n.habits_schedule_option_weekly));
      await tester.tap(find.text(l10n.social_save));
      await tester.pumpAndSettle();
      expect(find.text(l10n.habits_schedule_change_title), findsOneWidget);
      expect(find.text(l10n.habits_schedule_change_message), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, l10n.cancel).last);
      await tester.pumpAndSettle();
      expect(find.text(l10n.habits_schedule_change_title), findsNothing);
      expect(find.text(l10n.habits_edit_title), findsOneWidget, reason: 'still editing');
      expect(harness.habits.log, isEmpty, reason: 'nothing was written');
      expect(harness.habits.habits.single, habit('a', title: 'Вода'));
      harness.close();
    });

    testWidgets('a confirmed type change saves the schedule and starts the streak over', (tester) async {
      final harness = await _pump(tester, habits: [
        habit('a', title: 'Вода')
      ], done: {
        'a': [today.addDays(-2), today.addDays(-1)],
      });
      expect(find.textContaining(l10n.habits_streak(2)), findsOneWidget);

      await tester.tap(find.text('Вода'));
      await tester.pumpAndSettle();
      await _tapVisible(tester, _scheduleChip(l10n.habits_schedule_option_weekly));
      await tester.tap(find.text(l10n.social_save));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.habits_schedule_change_confirm));
      await tester.pumpAndSettle();

      final edited = harness.habits.habits.single;
      expect((edited.schedule, edited.streakResetOn), (HabitSchedule.weeklyTarget(3), today));
      expect(harness.stats.completions, hasLength(2), reason: 'the history is kept');
      expect(find.textContaining(l10n.habits_streak(2)), findsNothing);
      expect(find.text(l10n.habits_week_target_progress(0, 3)), findsOneWidget,
          reason: 'marks before the reset day do not count towards this week either');
      harness.close();
    });

    testWidgets('unrelated edits and new weekdays save without a dialog or a reset', (tester) async {
      final mondays = HabitSchedule.weekdays({DateTime.monday});
      final harness = await _pump(tester, habits: [habit('a', title: 'Зал', schedule: mondays)]);
      await tester.tap(find.text('Зал'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Зал'), 'Спортзал');
      await _tapVisible(tester, find.bySemanticsLabel(l10n.habits_weekday_5));
      await tester.tap(find.text(l10n.social_save));
      await tester.pumpAndSettle();

      expect(find.text(l10n.habits_schedule_change_title), findsNothing);
      final edited = harness.habits.habits.single;
      expect(edited.title, 'Спортзал');
      expect(edited.schedule, HabitSchedule.weekdays({DateTime.monday, DateTime.friday}));
      expect(edited.streakResetOn, isNull);
      harness.close();
    });

    testWidgets('weekday habits wait on their days off and cannot be marked then', (tester) async {
      // today is a Friday.
      final harness = await _pump(tester, habits: [
        habit('d', title: 'Вода'),
        habit('m', title: 'Зал', schedule: HabitSchedule.weekdays({DateTime.monday})),
      ]);
      expect(find.text(l10n.habits_section_other_days), findsOneWidget);
      expect(find.textContaining(l10n.habits_not_today), findsOneWidget);
      expect(_checkFor('Зал'), findsNothing);
      expect(find.text(l10n.habits_today_progress(0, 1)), findsOneWidget);

      await tester.tap(_checkFor('Вода'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.habits_today_all_done), findsOneWidget, reason: 'the Monday habit is not due today');
      harness.close();
    });
  });

  testWidgets('deleting asks for confirmation; cancel changes nothing', (tester) async {
    final harness = await _pump(tester, habits: [habit('a', title: 'Вода'), habit('b', title: 'Чтение')]);

    await _openMenu(tester, 'Вода');
    await tester.tap(find.text(l10n.habits_delete));
    await tester.pumpAndSettle();
    expect(find.text(l10n.habits_delete_title('Вода')), findsOneWidget);
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(harness.habits.habits, hasLength(2));

    await _openMenu(tester, 'Вода');
    await tester.tap(find.text(l10n.habits_delete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l10n.habits_delete));
    await tester.pumpAndSettle();
    expect(harness.habits.habits.map((h) => h.id), ['b']);
    expect(find.text('Вода'), findsNothing);
    harness.close();
  });

  testWidgets('the delete dialog offers pausing instead', (tester) async {
    final harness = await _pump(tester, habits: [habit('a', title: 'Вода')]);

    await _openMenu(tester, 'Вода');
    await tester.tap(find.text(l10n.habits_delete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l10n.habits_pause));
    await tester.pumpAndSettle();
    expect(harness.habits.habits.single.isActive, isFalse);
    expect(find.text(l10n.habits_section_paused), findsOneWidget);
    harness.close();
  });

  testWidgets('a failed save is explained', (tester) async {
    final harness = await _pump(tester, habits: [habit('a', title: 'Вода')]);
    harness.habits.failures.add('delete');

    await _openMenu(tester, 'Вода');
    await tester.tap(find.text(l10n.habits_delete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l10n.habits_delete));
    await tester.pumpAndSettle();
    expect(find.text(l10n.habits_error_delete), findsOneWidget);
    expect(find.text('Вода'), findsOneWidget);
    harness.close();
  });

  testWidgets('a failed load can be retried', (tester) async {
    final harness = _Harness();
    harness.habits.failLoad = true;
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    expect(find.text(l10n.habits_error_load), findsOneWidget);

    harness.habits.failLoad = false;
    await tester.tap(find.text(l10n.communities_retry));
    await tester.pumpAndSettle();
    expect(find.text(l10n.habits_empty_title), findsOneWidget);
    harness.close();
  });

  testWidgets('many habits with long names fit a small phone with large text', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final harness = await _pump(tester, habits: [
      for (var i = 0; i < 20; i++)
        habit('h$i', title: 'Очень длинное название привычки номер $i, которое не помещается', active: i % 5 != 0),
    ]);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    harness.close();
  });
}
