part of '../app_router.dart';

final _profileRoutes = [
  GoRoute(
    parentNavigatorKey: _profileRoutesNavigatorKey,
    path: ProfileRoutes.profile.path,
    name: ProfileRoutes.profile.name,
    builder: (_, state) => ProfileScreen(
      key: state.pageKey,
    ),
    routes: [
      GoRoute(
        path: 'friends',
        name: ProfileRoutes.friends.name,
        builder: (_, state) => FriendsScreen(key: state.pageKey),
      ),
      GoRoute(
        path: 'edit',
        name: ProfileRoutes.edit.name,
        builder: (_, state) => ProfileEditScreen(key: state.pageKey),
      ),
      GoRoute(
        path: 'privacy',
        name: ProfileRoutes.privacy.name,
        builder: (_, state) => PrivacyScreen(key: state.pageKey),
      ),
      GoRoute(
        path: 'notifications',
        name: ProfileRoutes.notificationSettings.name,
        builder: (_, state) => NotificationSettingsScreen(key: state.pageKey),
      ),
    ],
  ),
  GoRoute(
    path: ProfileRoutes.settings.path,
    name: ProfileRoutes.settings.name,
    builder: (_, state) => const WidgetsSettingsScreen(),
  ),
];
