import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/resources/assets.gen.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/feature/habit_stats/widget/habit_stats_scope.dart';
import 'package:go_habit/feature/home/widget/home_scope.dart';
import 'package:go_habit/feature/root/view/components/bottom_navbar.dart';
import 'package:go_habit/feature/social/bloc/friends_bloc.dart';
import 'package:go_habit/feature/social/bloc/my_profile_bloc.dart';
import 'package:go_router/go_router.dart';

class RootPage extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const RootPage({
    required this.navigationShell,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return HomeScope(
      child: HabitStatsScope(
        child: _NicknamePrompt(
          child: BlocSelector<FriendsBloc, FriendsState, int>(
            selector: (state) => state.incomingCount,
            builder: (context, incoming) =>
                RootShellLayout(navigationShell: navigationShell, profileBadgeCount: incoming),
          ),
        ),
      ),
    );
  }
}

/// Offers users without a nickname (new or existing accounts) to choose one, once per
/// app session. They may postpone it; habit tracking never depends on it.
class _NicknamePrompt extends StatefulWidget {
  final Widget child;

  const _NicknamePrompt({required this.child});

  @override
  State<_NicknamePrompt> createState() => _NicknamePromptState();
}

class _NicknamePromptState extends State<_NicknamePrompt> {
  static bool _shownThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybePrompt(context.read<MyProfileBloc>().state);
    });
  }

  void _maybePrompt(MyProfileState state) {
    if (_shownThisSession || !state.needsNickname) return;
    _shownThisSession = true;
    context.push(SocialRoutes.setup.path);
  }

  @override
  Widget build(BuildContext context) => BlocListener<MyProfileBloc, MyProfileState>(
        listenWhen: (previous, current) => !previous.needsNickname && current.needsNickname,
        listener: (context, state) => _maybePrompt(state),
        child: widget.child,
      );
}

/// Tab content with the floating [BottomNavBar] on top.
///
/// The selected tab comes from [navigationShell], so the bar always matches the
/// router, including redirects and deep links. Each branch keeps its own stack
/// and state (`StatefulShellRoute.indexedStack`).
class RootShellLayout extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  /// Incoming friend requests, shown on the profile button.
  final int profileBadgeCount;

  const RootShellLayout({required this.navigationShell, this.profileBadgeCount = 0, super.key});

  /// Selecting the current tab again returns to the root of its stack.
  void _onDestinationSelected(int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final obscured = BottomNavBar.obscuredHeight(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Pages see the bar as part of the bottom inset, so scroll views and
          // SafeArea keep their last items above it.
          MediaQuery(
            data: mediaQuery.copyWith(
              padding: mediaQuery.padding.copyWith(bottom: obscured),
              viewPadding: mediaQuery.viewPadding.copyWith(bottom: obscured),
            ),
            child: navigationShell,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomNavBar(
              currentIndex: navigationShell.currentIndex,
              onDestinationSelected: _onDestinationSelected,
              destinations: [
                BottomNavDestination(icon: Assets.navbarIcons.home, label: context.l10n.nav_home),
                BottomNavDestination(icon: Assets.navbarIcons.edit, label: context.l10n.nav_habits),
                BottomNavDestination(icon: Assets.navbarIcons.users, label: context.l10n.communities_title),
                // The notifications screen shows mock data; the badge mirrors it.
                BottomNavDestination(icon: Assets.navbarIcons.bell, label: context.l10n.notifications, badgeCount: 2),
              ],
              trailing: BottomNavDestination(
                icon: Assets.navbarIcons.user,
                label: context.l10n.profile_title,
                badgeCount: profileBadgeCount,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
