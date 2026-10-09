part of '../app_router.dart';

final _communityRoutes = [
  GoRoute(
    parentNavigatorKey: _communityRoutesNavigatorKey,
    path: CommunityRoutes.communities.path,
    name: CommunityRoutes.communities.name,
    builder: (_, state) => CommunitiesScreen(key: state.pageKey),
    routes: [
      GoRoute(
        path: ':templateId',
        name: CommunityRoutes.detail.name,
        builder: (_, state) => CommunityDetailScreen(
          key: state.pageKey,
          templateId: state.pathParameters['templateId']!,
        ),
      ),
    ],
  ),
];
