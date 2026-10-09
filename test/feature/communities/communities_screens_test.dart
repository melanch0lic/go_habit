import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/feature/categories/bloc/habit_category_bloc.dart';
import 'package:go_habit/feature/categories/domain/models/habit_category.dart';
import 'package:go_habit/feature/categories/domain/repositories/habit_category_repository.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/communities/view/communities_screen.dart';
import 'package:go_habit/feature/communities/view/community_detail_screen.dart';
import 'package:go_habit/feature/habit_stats/bloc/habit_stats_bloc.dart';
import 'package:go_habit/feature/habits/bloc/habits_bloc.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/l10n/app_localizations.dart';
import 'package:go_habit/l10n/app_localizations_ru.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_blocs.dart';
import 'community_fakes.dart';

final l10n = AppLocalizationsRu();

class _Categories implements HabitCategoryRepository {
  @override
  Future<List<HabitCategory>> getHabitCategories() async => [
        HabitCategory(id: 'education', name: 'Обучение', color: '#FB8C00'),
        HabitCategory(id: 'health', name: 'Здоровье', color: '#FF6B6B'),
        HabitCategory(id: 'art', name: 'Творчество', color: '#8E24AA'),
      ];
}

final _readingHabit = Habit(
  id: 'h1',
  title: 'Чтение книг',
  description: 'По вечерам',
  categoryId: 'education',
  icon: '📖',
  createdAt: DateTime(2026),
);

class _Harness {
  final repository = FakeCommunityRepository();
  final habitRepository = FakeHabitRepository();
  late final HabitsBloc habitsBloc;
  late final MockHabitStatsBloc statsBloc;
  late final HabitCategoryBloc categoryBloc;
  late final GoRouter router;

  _Harness({List<Habit> habits = const [], String? initialLocation}) {
    habitRepository.habits.addAll(habits);
    habitsBloc = HabitsBloc(habitRepository);
    // A fixed "today" with a completion of the ranked habit.
    statsBloc = MockHabitStatsBloc(loadedStats(completedDays: {
      'h1': [today]
    }, today: today));
    categoryBloc = HabitCategoryBloc(_Categories())..add(HabitInitialLoad());
    router = GoRouter(
      initialLocation: initialLocation ?? CommunityRoutes.communities.path,
      routes: [
        GoRoute(
          path: CommunityRoutes.communities.path,
          builder: (_, __) => CommunitiesView(repository: repository),
          routes: [
            GoRoute(
              path: ':templateId',
              builder: (_, state) =>
                  CommunityDetailView(templateId: state.pathParameters['templateId']!, repository: repository),
            ),
          ],
        ),
      ],
    );
  }

  Widget build() => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: habitsBloc),
          BlocProvider<HabitStatsBloc>.value(value: statsBloc),
          BlocProvider.value(value: categoryBloc),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.defaultTheme.lightTheme,
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
    habitsBloc.close();
    statsBloc.close();
    categoryBloc.close();
    router.dispose();
    repository.dispose();
    habitRepository.dispose();
  }
}

Future<_Harness> _pump(
  WidgetTester tester, {
  List<Habit> habits = const [],
  String? initialLocation,
  void Function(FakeCommunityRepository)? setUp,
}) async {
  final harness = _Harness(habits: habits, initialLocation: initialLocation);
  setUp?.call(harness.repository);
  addTearDown(harness.dispose);
  await tester.pumpWidget(harness.build());
  await tester.pumpAndSettle();
  return harness;
}

String _detail(String id) => CommunityRoutes.detailOf(id);

/// Publishes cached memberships once the screen listens to them.
Future<void> _publishMembership(WidgetTester tester, _Harness harness, CommunityMembership membership) async {
  harness.repository.memberships[membership.templateId] = membership;
  await harness.repository.join(membership.templateId);
  await tester.pumpAndSettle();
}

void main() {
  group('catalog', () {
    testWidgets('lists joinable communities with real participant counts', (tester) async {
      await _pump(tester);

      expect(find.text('Чтение'), findsOneWidget);
      expect(find.text('Прогулка'), findsOneWidget);
      expect(find.text('Архив'), findsNothing, reason: 'retired templates are not offered');
      expect(find.text(l10n.communities_members(3)), findsOneWidget);
      expect(find.text(l10n.communities_no_members_yet), findsWidgets);
    });

    testWidgets('search narrows the list and explains an empty result', (tester) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextField), 'прогул');
      await tester.pumpAndSettle();
      expect(find.text('Прогулка'), findsOneWidget);
      expect(find.text('Чтение'), findsNothing);

      await tester.enterText(find.byType(TextField), 'nothing like this');
      await tester.pumpAndSettle();
      expect(find.text(l10n.communities_empty_search), findsOneWidget);
    });

    testWidgets('category chips filter the list', (tester) async {
      await _pump(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Здоровье'));
      await tester.pumpAndSettle();
      expect(find.text('Чтение'), findsNothing);
      expect(find.text('Прогулка'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, l10n.communities_filter_all));
      await tester.pumpAndSettle();
      expect(find.text('Чтение'), findsOneWidget);
    });

    testWidgets('a failed load can be retried', (tester) async {
      final harness = await _pump(tester, setUp: (repo) => repo.failures['catalog'] = CommunityFailure.network);
      expect(find.textContaining(l10n.communities_load_failed), findsWidgets);

      harness.repository.failures.clear();
      await tester.tap(find.text(l10n.communities_retry).first);
      await tester.pumpAndSettle();
      expect(find.text('Чтение'), findsOneWidget);
    });

    testWidgets('offline: cached catalog, a notice, and no participant counts', (tester) async {
      await _pump(
        tester,
        setUp: (repo) => repo.catalog = const CommunityCatalog(templates: [reading], memberships: {}, isOffline: true),
      );
      expect(find.text(l10n.communities_offline_banner), findsOneWidget);
      expect(find.text('Чтение'), findsOneWidget);
      expect(find.text(l10n.communities_no_members_yet), findsNothing);
    });

    testWidgets('"My communities" is empty at first and leads back to the catalog', (tester) async {
      await _pump(tester);
      await tester.tap(find.text(l10n.communities_tab_mine));
      await tester.pumpAndSettle();
      expect(find.text(l10n.communities_empty_mine), findsOneWidget);

      await tester.tap(find.text(l10n.communities_browse_catalog));
      await tester.pumpAndSettle();
      expect(find.text(l10n.communities_intro), findsOneWidget);
    });

    testWidgets("'My communities' shows the ranked habit and this week's progress", (tester) async {
      await _pump(
        tester,
        habits: [_readingHabit],
        setUp: (repo) =>
            repo.memberships['reading'] = CommunityMembership(templateId: 'reading', joinedOn: today, habitId: 'h1'),
      );
      await tester.tap(find.text(l10n.communities_tab_mine));
      await tester.pumpAndSettle();

      expect(find.text(l10n.community_ranked_habit('Чтение книг')), findsOneWidget);
      expect(find.text(l10n.community_week_progress(1, 1)), findsOneWidget);
    });
  });

  group('community', () {
    testWidgets('opens from the catalog with rules and ranking', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Чтение'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.community_recommended_target('20 страниц')), findsOneWidget);
      expect(find.text(l10n.community_join), findsOneWidget);
      expect(find.text(l10n.community_rules_title), findsOneWidget);
      await tester.scrollUntilVisible(find.text(l10n.community_leaderboard_empty), 200);
      expect(find.text(l10n.community_not_ranked_yet), findsNothing, reason: 'no personal score before joining');
    });

    testWidgets("joining with a ranked habit uses the user's parameters", (tester) async {
      final harness = await _pump(tester, initialLocation: _detail('reading'));

      await tester.tap(find.text(l10n.community_join));
      await tester.pumpAndSettle();
      expect(find.text(l10n.join_option_ranked), findsOneWidget);
      expect(find.text(l10n.join_option_unranked), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Чтение'), 'Читаю перед сном');
      await tester.enterText(find.widgetWithText(TextFormField, '20'), '30');
      await tester.tap(find.text(l10n.community_join).last);
      await tester.pumpAndSettle();

      expect(harness.repository.log, contains('ranked:Читаю перед сном'));
      expect(find.text(l10n.community_joined_ranked), findsOneWidget);
    });

    testWidgets('joining without the ranking, then creating a ranked habit later', (tester) async {
      final harness = await _pump(tester, initialLocation: _detail('reading'));

      await tester.tap(find.text(l10n.community_join));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.join_option_unranked));
      await tester.pump();
      expect(find.widgetWithText(TextFormField, 'Чтение'), findsNothing, reason: 'no habit fields');
      await tester.tap(find.text(l10n.community_join).last);
      await tester.pumpAndSettle();

      expect(harness.repository.log, contains('join:reading'));
      expect(harness.repository.log.where((e) => e.startsWith('ranked')), isEmpty);
      expect(find.text(l10n.community_not_ranked), findsWidgets);

      await tester.tap(find.text(l10n.community_create_ranked_habit));
      await tester.pumpAndSettle();
      expect(find.text(l10n.join_option_unranked), findsNothing, reason: 'already a member');
      await tester.tap(find.text(l10n.community_create_habit_action));
      await tester.pumpAndSettle();

      expect(harness.repository.log, contains('ranked:Чтение'));
      expect(find.text(l10n.community_ranked_habit_created), findsOneWidget);
    });

    testWidgets('a similar existing habit is pointed out, not linked', (tester) async {
      await _pump(tester, habits: [_readingHabit], initialLocation: _detail('reading'));

      await tester.tap(find.text(l10n.community_join));
      await tester.pumpAndSettle();
      expect(find.text(l10n.create_habit_similar('Чтение книг')), findsOneWidget);
      expect(find.text('Чтение книг'), findsNothing, reason: 'existing habits are not offered for linking');
    });

    testWidgets('leaving asks first and keeps the habit', (tester) async {
      final harness = await _pump(tester, habits: [_readingHabit], initialLocation: _detail('reading'));
      await _publishMembership(
        tester,
        harness,
        CommunityMembership(templateId: 'reading', joinedOn: today, habitId: 'h1'),
      );

      await tester.ensureVisible(find.text(l10n.community_leave));
      await tester.tap(find.text(l10n.community_leave));
      await tester.pumpAndSettle();
      expect(find.text(l10n.community_leave_message), findsOneWidget);

      await tester.tap(find.text(l10n.community_leave_confirm));
      await tester.pumpAndSettle();
      expect(harness.repository.log, contains('leave:reading'));
      expect(find.text(l10n.community_left), findsOneWidget);
      expect(harness.habitRepository.log, isEmpty);
    });

    testWidgets("the ranking shows names or a neutral label, and the user's own row", (tester) async {
      await _pump(
        tester,
        initialLocation: _detail('reading'),
        setUp: (repo) => repo.leaderboardResult = CommunityLeaderboard.fromRows(const [
          LeaderboardEntry(
            rank: 1,
            displayName: 'Alice',
            isMe: false,
            completedDays: 5,
            eligibleDays: 5,
            consistency: 100,
            rankedCount: 3,
          ),
          LeaderboardEntry(rank: 2, isMe: true, completedDays: 5, eligibleDays: 7, consistency: 71.43, rankedCount: 3),
          LeaderboardEntry(rank: 3, isMe: false, completedDays: 0, eligibleDays: 2, consistency: 0, rankedCount: 3),
        ]),
      );
      await tester.scrollUntilVisible(find.text(l10n.community_member_fallback), 200);

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text(l10n.community_you), findsOneWidget);
      expect(find.text('71%'), findsOneWidget);
      expect(find.text(l10n.community_my_rank(2, 3)), findsOneWidget);
    });

    testWidgets('an offline ranking says so and can be retried', (tester) async {
      final harness = await _pump(
        tester,
        initialLocation: _detail('reading'),
        setUp: (repo) => repo.failures['leaderboard'] = CommunityFailure.offline,
      );
      await tester.scrollUntilVisible(find.text(l10n.community_leaderboard_offline), 200);

      harness.repository.failures.clear();
      await tester.tap(find.text(l10n.communities_retry));
      await tester.pumpAndSettle();
      expect(find.text(l10n.community_leaderboard_empty), findsOneWidget);
    });
  });

  group('layout', () {
    for (final location in [CommunityRoutes.communities.path, _detail('walking')]) {
      testWidgets('$location fits a small phone with large text', (tester) async {
        tester.view
          ..physicalSize = const Size(320, 568)
          ..devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await _pump(tester, initialLocation: location, habits: [_readingHabit]);
        expect(tester.takeException(), isNull);

        // The main vertical list (the catalog also has a horizontal chip row).
        final list = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
        await tester.drag(list, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
