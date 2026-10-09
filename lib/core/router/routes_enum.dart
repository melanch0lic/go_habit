const _authRoutesKey = '/auth_routes/';
const _homeRoutesKey = '/home_routes/';
const _calendarRoutesKey = '/calendar_routes/';
const _communityRoutesKey = '/community_routes/';
const _notificationRoutesKey = '/notification_routes/';
const _profileRoutesKey = '/profile_routes/';

enum AuthRoutes {
  login(path: '${_authRoutesKey}login'),
  register(path: '${_authRoutesKey}register'),
  forgotPassword(path: '${_authRoutesKey}forgot-password'),

  /// Sets a new password; only reachable with the recovery session from a reset link.
  resetPassword(path: '${_authRoutesKey}reset-password'),
  welcome(path: '${_authRoutesKey}welcome');

  final String path;

  const AuthRoutes({
    required this.path,
  });
}

enum HomeRoutes {
  home(path: '${_homeRoutesKey}home');

  final String path;

  const HomeRoutes({
    required this.path,
  });
}

enum CalendarRoutes {
  calendar(path: '${_calendarRoutesKey}calendar');

  final String path;

  const CalendarRoutes({
    required this.path,
  });
}

enum CommunityRoutes {
  /// Habit catalog and the user's communities (a main tab).
  communities(path: '${_communityRoutesKey}communities'),

  /// Community details; the last segment is the template id.
  detail(path: '${_communityRoutesKey}communities/:templateId');

  final String path;

  const CommunityRoutes({
    required this.path,
  });

  /// Location of the community of [templateId].
  static String detailOf(String templateId) => detail.path.replaceFirst(':templateId', Uri.encodeComponent(templateId));
}

enum ProfileRoutes {
  profile(path: '${_profileRoutesKey}profile'),
  settings(path: '${_profileRoutesKey}settings');

  final String path;

  const ProfileRoutes({
    required this.path,
  });
}

enum NotificationsRoutes {
  notifications(path: '${_notificationRoutesKey}notifications');

  final String path;

  const NotificationsRoutes({
    required this.path,
  });
}
