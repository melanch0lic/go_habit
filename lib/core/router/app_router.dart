import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/feature/auth/view/auth_screen.dart';
import 'package:go_habit/feature/auth/view/forgot_password_screen.dart';
import 'package:go_habit/feature/auth/view/registration_screen.dart';
import 'package:go_habit/feature/auth/view/reset_password_screen.dart';
import 'package:go_habit/feature/auth/view/splash_screen.dart';
import 'package:go_habit/feature/auth/view/welcome_screen.dart';
import 'package:go_habit/feature/communities/view/communities_screen.dart';
import 'package:go_habit/feature/communities/view/community_detail_screen.dart';
import 'package:go_habit/feature/habits/view/habits_page.dart';
import 'package:go_habit/feature/home/view/home_screen.dart';
import 'package:go_habit/feature/notifications/view/notification_settings_screen.dart';
import 'package:go_habit/feature/notifications/view/notifications_screen.dart';
import 'package:go_habit/feature/profile/view/profile_screen.dart';
import 'package:go_habit/feature/root/view/root_page.dart';
import 'package:go_habit/feature/settings/view/widgets_settings_screen.dart';
import 'package:go_habit/feature/social/view/friends_screen.dart';
import 'package:go_habit/feature/social/view/privacy_screen.dart';
import 'package:go_habit/feature/social/view/profile_edit_screen.dart';
import 'package:go_habit/feature/social/view/public_profile_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent, AuthState;

part 'routes/auth_routes.dart';
part 'routes/calendar_routes.dart';
part 'routes/community_routes.dart';
part 'routes/home_routes.dart';
part 'routes/notifications_routes.dart';
part 'routes/profile_routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'RootNavigatorKey');
final _homeRoutesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'HomeRoutesNavigatorKey');
final _calendarRoutesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'CalendarRoutesNavigatorKey');
final _communityRoutesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'CommunityRoutesNavigatorKey');
final _notificationRoutesBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'NotificationRoutesBranchNavigatorKey');
final _profileRoutesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'ProfileRoutesNavigatorKey');

class AppRouter {
  final bool Function() _isSignedIn;
  final AuthRefreshListenable _authRefresh;

  /// [authChanges] re-evaluates the redirect whenever the session changes: after
  /// sign-in, sign-out, when the session expires, or when a reset link opens a
  /// recovery session.
  AppRouter({required bool Function() isSignedIn, required Stream<AuthState> authChanges})
      : _isSignedIn = isSignedIn,
        _authRefresh = AuthRefreshListenable(authChanges);

  GoRouter get routerConfig => GoRouter(
        observers: [MyRouteObserver()],
        navigatorKey: rootNavigatorKey,
        debugLogDiagnostics: kDebugMode,
        initialLocation: '/',
        refreshListenable: _authRefresh,
        redirect: _redirect,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, state) => SplashScreen(key: state.pageKey),
          ),
          ..._authRoutes,
          _commonBottomNavigationBarShellRoute,
          // Full-screen pages above the tabs, reachable from every tab.
          GoRoute(
            parentNavigatorKey: rootNavigatorKey,
            path: SocialRoutes.user.path,
            builder: (_, state) => PublicProfileScreen(
              key: state.pageKey,
              publicId: state.pathParameters['publicId']!,
            ),
          ),
          GoRoute(
            parentNavigatorKey: rootNavigatorKey,
            path: SocialRoutes.setup.path,
            builder: (_, state) => ProfileEditScreen(key: state.pageKey, isSetup: true),
          ),
        ],
        errorBuilder: (context, state) => Center(
          child: Text(state.error.toString()),
        ),
      );

  String? _redirect(BuildContext context, GoRouterState state) => resolveAuthRedirect(
        location: state.matchedLocation,
        isSignedIn: _isSignedIn(),
        passwordRecovery: _authRefresh.takePasswordRecovery(),
      );
}

/// Where the router sends the user for [location], or null to stay.
///
/// - A reset link opens the new-password screen ([passwordRecovery]), even over the
///   splash screen when the link launched the app.
/// - Otherwise the splash screen ("/") decides on its own.
/// - Signed-out users only see the auth screens (not the new-password screen, which
///   needs the recovery session).
/// - Signed-in users skip sign-in and registration and go straight to the app, so
///   screens never navigate after a successful sign-in themselves.
@visibleForTesting
String? resolveAuthRedirect({required String location, required bool isSignedIn, bool passwordRecovery = false}) {
  final resetPassword = AuthRoutes.resetPassword.path;
  if (passwordRecovery && isSignedIn) return location == resetPassword ? null : resetPassword;
  if (location == '/') return null;

  final isAuthRoute = AuthRoutes.values.any((route) => route.path == location);
  if (!isSignedIn) return isAuthRoute && location != resetPassword ? null : AuthRoutes.login.path;
  if (isAuthRoute && location != resetPassword) return HomeRoutes.home.path;
  return null;
}

@visibleForTesting
class AuthRefreshListenable extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;
  bool _passwordRecovery = false;

  AuthRefreshListenable(Stream<AuthState> changes) {
    _subscription = changes.listen(
      (state) {
        if (state.event == AuthChangeEvent.passwordRecovery) _passwordRecovery = true;
        notifyListeners();
      },
      // Failed email links surface as stream errors; AuthBloc reports them.
      onError: (Object _) {},
    );
  }

  /// Whether a reset link was opened since the last call. Consumed once, so the user
  /// can leave the new-password screen afterwards.
  bool takePasswordRecovery() {
    final value = _passwordRecovery;
    _passwordRecovery = false;
    return value;
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final _commonBottomNavigationBarShellRoute = StatefulShellRoute.indexedStack(
  branches: [
    _homeRoutesBranch,
    _calendarRoutesBranch,
    _communityRoutesBranch,
    _notificationRoutesBranch,
    _profileRoutesBranch,
  ],
  builder: (_, state, navigationShell) => RootPage(
    key: state.pageKey,
    navigationShell: navigationShell,
  ),
);

final _homeRoutesBranch = StatefulShellBranch(
  observers: [MyRouteObserver()],
  navigatorKey: _homeRoutesNavigatorKey,
  initialLocation: HomeRoutes.home.path,
  routes: [
    ..._homeRoutes,
  ],
);

final _calendarRoutesBranch = StatefulShellBranch(
  observers: [MyRouteObserver()],
  navigatorKey: _calendarRoutesNavigatorKey,
  initialLocation: CalendarRoutes.calendar.path,
  routes: [
    ..._calendarRoutes,
  ],
);

final _communityRoutesBranch = StatefulShellBranch(
  observers: [MyRouteObserver()],
  navigatorKey: _communityRoutesNavigatorKey,
  initialLocation: CommunityRoutes.communities.path,
  routes: [
    ..._communityRoutes,
  ],
);

final _notificationRoutesBranch = StatefulShellBranch(
  observers: [MyRouteObserver()],
  navigatorKey: _notificationRoutesBranchNavigatorKey,
  initialLocation: NotificationsRoutes.notifications.path,
  routes: [
    ..._notificationRoutes,
  ],
);

final _profileRoutesBranch = StatefulShellBranch(
  observers: [MyRouteObserver()],
  navigatorKey: _profileRoutesNavigatorKey,
  initialLocation: ProfileRoutes.profile.path,
  routes: [
    ..._profileRoutes,
  ],
);

class MyRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    debugPrint("Route pushed: ${route.settings.name ?? 'Unknown'} with arguments: ${route.settings.arguments}");
    debugPrint("Previous Route: ${previousRoute?.settings.name ?? 'None'}");
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<Object?> route, Route<Object?>? previousRoute) {
    debugPrint("Route popped: ${route.settings.name ?? 'Unknown'}");
    debugPrint("Previous Route: ${previousRoute?.settings.name ?? 'None'}");
    super.didPop(route, previousRoute);
  }
}
