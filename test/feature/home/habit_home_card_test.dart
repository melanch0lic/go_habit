import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/core/ui_kit/habit_card_types.dart';
import 'package:go_habit/feature/categories/bloc/habit_category_bloc.dart';
import 'package:go_habit/feature/categories/domain/models/habit_category.dart';
import 'package:go_habit/feature/habit_stats/bloc/habit_stats_bloc.dart';
import 'package:go_habit/feature/habits/bloc/habits_bloc.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/feature/home/bloc/habit_card_settings_bloc.dart';
import 'package:go_habit/feature/home/view/components/habit_home_card.dart';
import 'package:go_habit/feature/home/view/components/habit_home_list.dart';
import 'package:go_habit/l10n/app_localizations.dart';
import 'package:go_habit/l10n/app_localizations_ru.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mock_blocs.dart';
import '../habits/habits_fakes.dart';

final l10n = AppLocalizationsRu();
final _category = HabitCategory(id: 'health', name: 'Здоровье', color: '#FF6B6B');

// Friday 2026-10-09: Monday–Friday are this week's days.
final _stats = loadedStats(
  today: today,
  completedDays: {
    'a': [today.addDays(-4), today.addDays(-2), today],
  },
);

Widget _app(Widget child, {HabitStatsState? stats, List<BlocProvider> extra = const []}) => MultiBlocProvider(
      providers: [
        BlocProvider<HabitStatsBloc>.value(value: MockHabitStatsBloc(stats ?? _stats)),
        ...extra,
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
        home: Scaffold(body: child),
      ),
    );

void main() {
  group('card', () {
    testWidgets("linear mode shows this week's real progress, the streak and the done state", (tester) async {
      await tester.pumpWidget(_app(HabitHomeCard(habit: habit('a', title: 'Вода'), category: _category)));
      await tester.pumpAndSettle();

      expect(find.text(l10n.community_week_progress(3, 5)), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Здоровье · ${l10n.habits_streak(1)}'), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.habit_unmark_done), findsOneWidget, reason: 'done today');
    });

    testWidgets('a weekly goal shows its schedule, progress towards the target and streak in weeks', (tester) async {
      final weekly = habit('a', title: 'Бег', schedule: HabitSchedule.weeklyTarget(3));
      await tester.pumpWidget(_app(HabitHomeCard(habit: weekly, category: _category)));
      await tester.pumpAndSettle();

      expect(find.text(l10n.habits_week_target_progress(3, 3)), findsOneWidget);
      expect(
        find.text('Здоровье · ${l10n.habits_schedule_times_per_week(3)} · ${l10n.habits_streak_weeks(1)}'),
        findsOneWidget,
      );
    });

    testWidgets('circular mode draws the week as a ring around the icon', (tester) async {
      await tester.pumpWidget(_app(HabitHomeCard(
        habit: habit('a', title: 'Вода'),
        category: _category,
        displayMode: HabitCardDisplayMode.circular,
      )));
      await tester.pumpAndSettle();

      final ring = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
      expect(ring.value, closeTo(0.6, 0.001));
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('minimal mode has no progress', (tester) async {
      await tester.pumpWidget(_app(HabitHomeCard(
        habit: habit('a', title: 'Вода'),
        category: _category,
        displayMode: HabitCardDisplayMode.none,
      )));
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('list', () {
    late FakeHabitRepository repository;
    late HabitsBloc habitsBloc;
    late HabitCategoryBloc categoryBloc;
    late HabitCardSettingsBloc settingsBloc;

    Future<void> pumpList(WidgetTester tester, List<dynamic> habits) async {
      SharedPreferences.setMockInitialValues({});
      repository = FakeHabitRepository(habits.cast());
      habitsBloc = HabitsBloc(repository);
      categoryBloc = HabitCategoryBloc(FakeCategoryRepository())..add(HabitInitialLoad());
      settingsBloc = HabitCardSettingsBloc(await SharedPreferences.getInstance());
      await tester.pumpWidget(_app(
        const CustomScrollView(slivers: [HabitHomeList()]),
        extra: [
          BlocProvider<HabitsBloc>.value(value: habitsBloc),
          BlocProvider<HabitCategoryBloc>.value(value: categoryBloc),
          BlocProvider<HabitCardSettingsBloc>.value(value: settingsBloc),
        ],
      ));
      await tester.pumpAndSettle();
    }

    void close() {
      habitsBloc.close();
      categoryBloc.close();
      settingsBloc.close();
      repository.dispose();
    }

    testWidgets("shows today's habits only; an unknown category does not crash", (tester) async {
      await pumpList(tester, [
        habit('a', title: 'Вода'),
        habit('p', title: 'Бег', active: false),
        habit('x', title: 'Без категории', category: 'gone'),
      ]);
      expect(find.text('Вода'), findsOneWidget);
      expect(find.text('Бег'), findsNothing, reason: 'paused habits are not scheduled');
      expect(find.text('Без категории'), findsOneWidget);
      expect(find.textContaining(l10n.habits_category_other), findsOneWidget);
      close();
    });

    testWidgets('weekly goals are listed; weekday habits only on their days', (tester) async {
      // today is a Friday.
      await pumpList(tester, [
        habit('w', title: 'Бег', schedule: HabitSchedule.weeklyTarget(2)),
        habit('f', title: 'Бассейн', schedule: HabitSchedule.weekdays({DateTime.friday})),
        habit('m', title: 'Зал', schedule: HabitSchedule.weekdays({DateTime.monday})),
      ]);
      expect(find.text('Бег'), findsOneWidget);
      expect(find.text('Бассейн'), findsOneWidget);
      expect(find.text('Зал'), findsNothing);
      close();
    });

    testWidgets('nothing scheduled offers to add a habit', (tester) async {
      await pumpList(tester, [habit('p', active: false)]);
      expect(find.text(l10n.habits_today_nothing), findsOneWidget);
      expect(find.text(l10n.habits_add), findsOneWidget);
      close();
    });
  });

  testWidgets('golden: the three display modes', (tester) async {
    tester.view
      ..physicalSize = const Size(400, 480)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(Column(
      children: [
        for (final mode in HabitCardDisplayMode.values)
          HabitHomeCard(
            habit: habit('a', title: 'Пить воду'),
            category: _category,
            displayMode: mode,
          ),
        HabitHomeCard(habit: habit('b', title: 'Читать 20 страниц', icon: '📚'), category: _category),
      ],
    )));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Column).first, matchesGoldenFile('goldens/habit_home_card_modes.png'));
  });
}
