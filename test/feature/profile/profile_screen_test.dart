import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/feature/habit_stats/bloc/habit_stats_bloc.dart';
import 'package:go_habit/feature/habits/bloc/habits_bloc.dart';
import 'package:go_habit/feature/language/data/repository/language_repository_implementation.dart';
import 'package:go_habit/feature/language/domain/bloc/language_bloc.dart';
import 'package:go_habit/feature/profile/widget/settings_section.dart';
import 'package:go_habit/feature/social/bloc/friends_bloc.dart';
import 'package:go_habit/feature/social/bloc/my_profile_bloc.dart';
import 'package:go_habit/feature/social/view/my_profile_section.dart';
import 'package:go_habit/feature/theme/theme_cubit.dart';
import 'package:go_habit/l10n/app_localizations.dart';
import 'package:go_habit/l10n/app_localizations_ru.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mock_blocs.dart';
import '../habits/habits_fakes.dart';
import '../social/social_fakes.dart';

final l10n = AppLocalizationsRu();

/// The page's vertical list (segmented buttons and chips are not scrollable).
final _page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 100, scrollable: _page);
  await tester.pumpAndSettle();
}

/// The profile screen's content (header, statistics, social links, settings) with
/// real blocs on fakes. The theme follows the [ThemeCubit], as in the app.
class _Profile {
  final FakeSocialRepository social;
  final habits = FakeHabitRepository([habit('a'), habit('p', active: false)]);
  late final MyProfileBloc profileBloc = MyProfileBloc(social)..add(const MyProfileRequested());
  late final FriendsBloc friendsBloc = FriendsBloc(social);
  late final HabitsBloc habitsBloc = HabitsBloc(habits);
  final statsBloc = MockHabitStatsBloc(loadedStats(today: today, completedDays: {
    'a': [today]
  }));
  final themeCubit = ThemeCubit();
  final languageBloc = LanguageBloc(LanguageRepositoryImplementation(), deviceLocale: 'ru');

  _Profile(FakeSocialServer server) : social = FakeSocialRepository(server, 'me');

  Widget build({String? email = 'me@example.test'}) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: profileBloc),
          BlocProvider.value(value: friendsBloc),
          BlocProvider.value(value: habitsBloc),
          BlocProvider<HabitStatsBloc>.value(value: statsBloc),
          BlocProvider.value(value: themeCubit),
          BlocProvider.value(value: languageBloc),
        ],
        child: BlocBuilder<ThemeCubit, ThemeState>(
          builder: (context, state) => MaterialApp(
            theme: AppTheme.defaultTheme.lightTheme,
            darkTheme: AppTheme.defaultTheme.darkTheme,
            themeMode: state.themeMode,
            locale: const Locale('ru'),
            supportedLocales: const [Locale('ru'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  MyProfileSection(email: email),
                  const SizedBox(height: AppSpacing.section),
                  const SettingsSection(),
                ],
              ),
            ),
          ),
        ),
      );

  /// Closing is not awaited: it would never complete inside the fake async zone.
  void dispose() {
    profileBloc.close();
    friendsBloc.close();
    habitsBloc.close();
    statsBloc.close();
    themeCubit.close();
    languageBloc.close();
    habits.dispose();
    social.dispose();
  }
}

Future<_Profile> _open(WidgetTester tester,
    {String? nickname = 'Mia', String? bio, String? email = 'me@example.test'}) async {
  SharedPreferences.setMockInitialValues({});
  final server = FakeSocialServer()..addUser('me', nickname: nickname);
  if (nickname != null && bio != null) server.updateProfile('me', nickname: nickname, bio: bio);
  final profile = _Profile(server);
  addTearDown(profile.dispose);
  await tester.pumpWidget(profile.build(email: email));
  await tester.pumpAndSettle();
  return profile;
}

void main() {
  testWidgets('groups identity, statistics, social links and settings', (tester) async {
    await _open(tester, bio: 'Бегаю по утрам');

    expect(find.text('@Mia'), findsOneWidget);
    expect(find.text('Бегаю по утрам'), findsOneWidget);
    expect(find.text('me@example.test'), findsOneWidget, reason: 'the private email, for the owner only');
    expect(find.text(l10n.social_edit_profile), findsOneWidget, reason: 'editing is the visible primary action');
    await _scrollTo(tester, find.text(l10n.social_stat_active_habits));
    expect(find.text(l10n.social_stat_active_habits), findsOneWidget);
    for (final title in [
      l10n.profile_section_stats,
      l10n.profile_section_social,
      l10n.profile_section_settings,
      l10n.profile_section_about,
    ]) {
      await _scrollTo(tester, find.text(title));
      expect(find.bySemanticsLabel(title), findsOneWidget, reason: '$title is a section header');
    }
    await _scrollTo(tester, find.text(l10n.sign_out));
    expect(find.text(l10n.sign_out), findsOneWidget);
  });

  testWidgets('without a nickname, choosing one is the primary action', (tester) async {
    await _open(tester, nickname: null);
    expect(find.text(l10n.social_no_nickname), findsOneWidget);
    expect(
      find.ancestor(
          of: find.text(l10n.social_set_nickname), matching: find.byWidgetPredicate((w) => w is FilledButton)),
      findsOneWidget,
    );
    expect(find.text(l10n.social_edit_profile), findsNothing);
  });

  testWidgets('the theme selector switches the whole app and stores the choice', (tester) async {
    final profile = await _open(tester);
    BuildContext context() => tester.element(find.byType(SettingsSection));
    expect(Theme.of(context()).brightness, Brightness.light, reason: 'system default in tests is light');

    await _scrollTo(tester, find.text(l10n.theme_dark));
    await tester.tap(find.text(l10n.theme_dark));
    await tester.pumpAndSettle();
    expect(profile.themeCubit.state.themeMode, ThemeMode.dark);
    expect(Theme.of(context()).brightness, Brightness.dark);
    expect((await SharedPreferences.getInstance()).getString('theme'), 'dark');

    await tester.tap(find.text(l10n.theme_system));
    await tester.pumpAndSettle();
    expect(profile.themeCubit.state.themeMode, ThemeMode.system);
    expect(Theme.of(context()).brightness, Brightness.light);
  });

  testWidgets('the language selector changes the app language', (tester) async {
    final profile = await _open(tester);
    await _scrollTo(tester, find.text('English'));
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(profile.languageBloc.state.currentLocale, 'en');
  });

  for (final dark in [false, true]) {
    testWidgets('long names and large text fit a small phone (${dark ? 'dark' : 'light'})', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 568)
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      if (dark) tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await _open(
        tester,
        nickname: 'Very_long_nickname1',
        bio: 'Очень длинное описание профиля, которое занимает несколько строк и должно аккуратно обрезаться',
        email: 'a.really.long.address.for.testing@example-domain.test',
      );
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.sign_out), findsOneWidget);
    });
  }
}
