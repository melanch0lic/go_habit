import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/feature/social/bloc/friends_bloc.dart';
import 'package:go_habit/feature/social/bloc/my_profile_bloc.dart';
import 'package:go_habit/feature/social/domain/models/social.dart';
import 'package:go_habit/feature/social/view/friends_screen.dart';
import 'package:go_habit/feature/social/view/profile_edit_screen.dart';
import 'package:go_habit/feature/social/view/public_profile_screen.dart';
import 'package:go_habit/l10n/app_localizations.dart';
import 'package:go_habit/l10n/app_localizations_ru.dart';
import 'package:go_router/go_router.dart';

import '../communities/community_fakes.dart' show FakeCommunityRepository;
import 'social_fakes.dart';

final l10n = AppLocalizationsRu();

/// The social screens of one signed-in user, against the shared fake server.
class _App {
  final FakeSocialRepository repository;
  final communities = FakeCommunityRepository();
  late final MyProfileBloc profileBloc = MyProfileBloc(repository)..add(const MyProfileRequested());
  late final FriendsBloc friendsBloc = FriendsBloc(repository);
  late final GoRouter router;

  _App(FakeSocialServer server, String userId, {required String initialLocation})
      : repository = FakeSocialRepository(server, userId) {
    router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: ProfileRoutes.friends.path, builder: (_, __) => FriendsView(repository: repository)),
        GoRoute(
          path: ProfileRoutes.edit.path,
          builder: (_, __) => ProfileEditView(repository: repository, debounce: Duration.zero),
        ),
        GoRoute(
          path: SocialRoutes.user.path,
          builder: (_, state) => PublicProfileView(
            publicId: state.pathParameters['publicId']!,
            repository: repository,
            communities: communities,
          ),
        ),
      ],
    );
  }

  Widget build() => MultiBlocProvider(
        providers: [BlocProvider.value(value: profileBloc), BlocProvider.value(value: friendsBloc)],
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
    profileBloc.close();
    friendsBloc.close();
    router.dispose();
    repository.dispose();
    communities.dispose();
  }
}

Future<_App> _open(WidgetTester tester, FakeSocialServer server, String userId, String location) async {
  final app = _App(server, userId, initialLocation: location);
  addTearDown(app.dispose);
  await tester.pumpWidget(app.build());
  await tester.pumpAndSettle();
  return app;
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

FakeSocialServer _server() => FakeSocialServer()
  ..addUser('alice', weekCompleted: 5, weekEligible: 5, memberOf: ['reading'])
  ..addUser('bob', nickname: 'Bob', weekCompleted: 2, weekEligible: 5, memberOf: ['reading', 'walking'])
  ..addUser('carol', nickname: 'Carol');

void main() {
  testWidgets('end to end: nickname, search, request, accept, profiles, ranking, removal and blocking', (tester) async {
    final server = _server();
    final aliceId = server.publicIdOf('alice');
    final bobId = server.publicIdOf('bob');

    // 1. Alice sets a nickname; availability is checked while typing.
    await _open(tester, server, 'alice', ProfileRoutes.edit.path);
    await tester.enterText(find.byType(TextField).first, 'bob');
    await tester.pumpAndSettle();
    expect(find.text(l10n.social_nickname_taken), findsOneWidget, reason: 'case-insensitive');
    await tester.enterText(find.byType(TextField).first, 'Alice_1');
    await tester.pumpAndSettle();
    expect(find.text(l10n.social_nickname_available), findsOneWidget);
    await _tapText(tester, l10n.social_save);
    expect(server.profileOf('alice').nickname, 'Alice_1');

    // 2–3. Bob finds Alice by nickname and sends a request.
    await _open(tester, server, 'bob', ProfileRoutes.friends.path);
    await tester.enterText(find.byType(TextField), 'alice_1');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('@Alice_1'), findsOneWidget);
    await _tapText(tester, l10n.social_add_friend);
    expect(find.text(l10n.social_request_sent), findsOneWidget);
    expect(find.text(l10n.social_cancel_request), findsWidgets);

    // 4. Alice sees the request and accepts it.
    await _open(tester, server, 'alice', ProfileRoutes.friends.path);
    expect(find.descendant(of: find.byType(Badge), matching: find.text('1')), findsOneWidget);
    await _openTab(tester, l10n.social_tab_requests);
    expect(find.text('@Bob'), findsOneWidget);
    await _tapText(tester, l10n.social_accept);
    expect(find.text(l10n.social_now_friends), findsOneWidget);

    // 5. Both see each other as friends.
    await _openTab(tester, l10n.social_tab_friends);
    expect(find.text('@Bob'), findsOneWidget);
    await _open(tester, server, 'bob', ProfileRoutes.friends.path);
    expect(find.text('@Alice_1'), findsOneWidget);
    await _openTab(tester, l10n.social_tab_requests);
    expect(find.text(l10n.social_request_accepted_notice('@Alice_1')), findsOneWidget);

    // 6. Bob opens Alice's profile: friends see her statistics and shared communities.
    await _open(tester, server, 'bob', SocialRoutes.userOf(aliceId));
    expect(find.text(l10n.social_friends_badge), findsWidgets);
    expect(find.text(l10n.social_stats_title), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text(l10n.social_shared_communities), findsOneWidget);
    expect(find.text('Чтение'), findsOneWidget, reason: 'only the community they share');
    expect(find.text('Прогулка'), findsNothing);

    // 7. The friends ranking shows both with valid data.
    await _open(tester, server, 'bob', ProfileRoutes.friends.path);
    await _openTab(tester, l10n.social_tab_ranking);
    expect(find.text('@Alice_1'), findsOneWidget);
    expect(find.text(l10n.community_you), findsOneWidget);
    expect(find.text(l10n.community_my_rank(2, 2)), findsOneWidget);

    // 8. Alice removes Bob, then blocks him: Bob can no longer find her.
    await _open(tester, server, 'alice', SocialRoutes.userOf(bobId));
    await _tapText(tester, l10n.social_remove_friend);
    expect(find.text(l10n.social_remove_message), findsOneWidget);
    await _tapText(tester, l10n.social_remove_friend);
    expect(find.text(l10n.social_add_friend), findsOneWidget);
    expect(server.areFriends('alice', 'bob'), isFalse);

    await tester.tap(find.byTooltip(l10n.social_more_actions));
    await tester.pumpAndSettle();
    await _tapText(tester, l10n.social_block);
    await _tapText(tester, l10n.social_block);
    expect(find.text(l10n.social_unblock), findsWidgets);

    await _open(tester, server, 'bob', ProfileRoutes.friends.path);
    await tester.enterText(find.byType(TextField), 'Alice_1');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text(l10n.social_search_empty('Alice_1')), findsOneWidget, reason: 'the block is not revealed');
  });

  group('friends screen', () {
    testWidgets('empty states lead to search; requests can be rejected and cancelled', (tester) async {
      final server = _server();
      await FakeSocialRepository(server, 'carol').sendRequest(server.publicIdOf('bob'));
      final app = await _open(tester, server, 'bob', ProfileRoutes.friends.path);
      expect(find.text(l10n.social_no_friends), findsOneWidget);

      await _openTab(tester, l10n.social_tab_requests);
      await _tapText(tester, l10n.social_reject);
      expect(find.text(l10n.social_request_rejected), findsOneWidget);
      expect(find.text(l10n.social_no_requests), findsOneWidget);

      await app.repository.sendRequest(server.publicIdOf('carol'));
      app.friendsBloc.add(const FriendsRequested());
      await tester.pumpAndSettle();
      expect(find.text(l10n.social_outgoing), findsOneWidget);
      await _tapText(tester, l10n.social_cancel_request);
      expect(find.text(l10n.social_request_cancelled), findsOneWidget);
      expect(server.pairCount, 0);
    });

    testWidgets('a failed load can be retried', (tester) async {
      final server = _server();
      final app = _App(server, 'bob', initialLocation: ProfileRoutes.friends.path);
      addTearDown(app.dispose);
      app.repository.failures['graph'] = SocialFailure.network;
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      expect(find.text(l10n.social_error_network), findsOneWidget);

      app.repository.failures.clear();
      await _tapText(tester, l10n.communities_retry);
      expect(find.text(l10n.social_no_friends), findsOneWidget);
    });

    testWidgets('users without a nickname are invited to choose one', (tester) async {
      await _open(tester, _server(), 'alice', ProfileRoutes.friends.path);
      expect(find.text(l10n.social_nickname_callout), findsOneWidget);
    });
  });

  group('public profile', () {
    testWidgets('strangers see only public fields', (tester) async {
      await _open(tester, _server(), 'carol', SocialRoutes.userOf('pub-bob'));
      expect(find.text('@Bob'), findsWidgets);
      expect(find.text(l10n.social_stats_hidden), findsOneWidget);
      expect(find.text(l10n.social_shared_communities), findsNothing);
      expect(find.text(l10n.social_add_friend), findsOneWidget);
    });

    testWidgets('statistics shared with everyone are visible to strangers', (tester) async {
      final server = _server()..updatePrivacy('bob', ProfileVisibility.everyone, ProfileVisibility.nobody);
      await _open(tester, server, 'carol', SocialRoutes.userOf('pub-bob'));
      expect(find.text(l10n.social_stats_title), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text(l10n.social_shared_communities), findsNothing, reason: 'communities stay hidden');
    });

    testWidgets('an unknown or hiding user reads as not found', (tester) async {
      await _open(tester, _server(), 'bob', SocialRoutes.userOf('pub-nobody'));
      expect(find.text(l10n.social_error_not_found), findsOneWidget);
    });
  });

  group('profile editing', () {
    testWidgets('invalid nicknames are explained and cannot be saved', (tester) async {
      final app = await _open(tester, _server(), 'alice', ProfileRoutes.edit.path);
      await tester.enterText(find.byType(TextField).first, 'admin');
      await tester.pumpAndSettle();
      expect(find.text(l10n.social_nickname_reserved), findsOneWidget);
      final save = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, l10n.social_save));
      expect(save.onPressed, isNull);
      expect(app.repository.log.where((e) => e.startsWith('status')), isEmpty);
    });

    testWidgets('a save that loses a race reports the taken nickname', (tester) async {
      final server = _server();
      await _open(tester, server, 'alice', ProfileRoutes.edit.path);
      await tester.enterText(find.byType(TextField).first, 'Dave');
      await tester.pumpAndSettle();
      server.updateProfile('carol', nickname: 'dave');
      await _tapText(tester, l10n.social_save);
      expect(find.text(l10n.social_nickname_taken), findsWidgets);
      expect(server.profileOf('alice').nickname, isNull);
    });
  });

  group('layout', () {
    for (final (name, location) in [
      ('friends', ProfileRoutes.friends.path),
      ('profile', SocialRoutes.userOf('pub-bob')),
      ('edit', ProfileRoutes.edit.path),
    ]) {
      testWidgets('$name fits a small phone with large text', (tester) async {
        tester.view
          ..physicalSize = const Size(320, 568)
          ..devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await _open(tester, _server(), 'carol', location);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
