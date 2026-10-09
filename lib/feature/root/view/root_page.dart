import 'package:flutter/material.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/resources/assets.gen.dart';
import 'package:go_habit/feature/habit_stats/widget/habit_stats_scope.dart';
import 'package:go_habit/feature/home/widget/home_scope.dart';
import 'package:go_habit/feature/root/view/components/bottom_navbar.dart';
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
        child: RootShellLayout(navigationShell: navigationShell),
      ),
    );
  }
}

/// Tab content with the floating [BottomNavBar] on top.
///
/// The selected tab comes from [navigationShell], so the bar always matches the
/// router, including redirects and deep links. Each branch keeps its own stack
/// and state (`StatefulShellRoute.indexedStack`).
class RootShellLayout extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const RootShellLayout({required this.navigationShell, super.key});

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
                // The notifications screen shows mock data; the badge mirrors it.
                BottomNavDestination(icon: Assets.navbarIcons.bell, label: context.l10n.notifications, badgeCount: 2),
              ],
              trailing: BottomNavDestination(icon: Assets.navbarIcons.user, label: context.l10n.profile_title),
            ),
          ),
        ],
      ),
    );
  }
}
