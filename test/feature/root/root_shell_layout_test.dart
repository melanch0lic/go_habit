import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/feature/root/view/components/bottom_navbar.dart';
import 'package:go_habit/feature/root/view/root_page.dart';
import 'package:go_habit/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

class _CounterPage extends StatefulWidget {
  final String name;

  const _CounterPage(this.name);

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${widget.name}: $_count'),
              Text('inset ${widget.name}: ${MediaQuery.paddingOf(context).bottom}'),
              TextButton(onPressed: () => setState(() => _count++), child: Text('increment ${widget.name}')),
              TextButton(onPressed: () => context.go('/${widget.name}/details'), child: Text('open ${widget.name}')),
            ],
          ),
        ),
      );
}

GoRouter _router() => GoRouter(
      initialLocation: '/a',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => RootShellLayout(navigationShell: shell),
          branches: [
            for (final name in ['a', 'b', 'c', 'd', 'e'])
              StatefulShellBranch(routes: [
                GoRoute(
                  path: '/$name',
                  builder: (_, __) => _CounterPage(name),
                  routes: [
                    GoRoute(path: 'details', builder: (_, __) => Scaffold(body: Text('details $name'))),
                  ],
                ),
              ]),
          ],
        ),
      ],
    );

void main() {
  late GoRouter router;

  Future<void> pumpApp(WidgetTester tester) async {
    router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.defaultTheme.lightTheme,
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
  }

  String? selectedLabel(WidgetTester tester) {
    for (final label in ['Home', 'Habits', 'Communities', 'Notifications', 'Profile']) {
      if (find.text(label).evaluate().isNotEmpty) return label;
    }
    return null;
  }

  testWidgets('tapping a tab switches the branch and the highlight', (tester) async {
    await pumpApp(tester);
    expect(selectedLabel(tester), 'Home');

    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('e: 0'), findsOneWidget);
    expect(selectedLabel(tester), 'Profile');
  });

  testWidgets('each tab keeps its state when switching away and back', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('increment a'));
    await tester.pump();

    await tester.tap(find.byTooltip('Habits'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();

    expect(find.text('a: 1'), findsOneWidget);
  });

  testWidgets('nested stacks are kept per tab; tapping the active tab returns to its root', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('open a'));
    await tester.pumpAndSettle();
    expect(find.text('details a'), findsOneWidget);

    await tester.tap(find.byTooltip('Habits'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(find.text('details a'), findsOneWidget, reason: 'switching tabs preserves the nested route');

    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(find.text('details a'), findsNothing);
    expect(find.text('a: 0'), findsOneWidget);
  });

  testWidgets('the highlight follows navigation that does not come from the bar', (tester) async {
    await pumpApp(tester);

    router.go('/d');
    await tester.pumpAndSettle();

    expect(selectedLabel(tester), 'Notifications');
  });

  testWidgets('rapid tab switching ends on the last tapped tab without errors', (tester) async {
    await pumpApp(tester);
    for (final label in ['Habits', 'Communities', 'Notifications', 'Profile', 'Habits']) {
      await tester.tap(find.byTooltip(label));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(selectedLabel(tester), 'Habits');
    expect(find.text('b: 0'), findsOneWidget);
  });

  testWidgets('the communities tab opens its own branch', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Communities'));
    await tester.pumpAndSettle();

    expect(find.text('c: 0'), findsOneWidget);
    expect(selectedLabel(tester), 'Communities');
  });

  testWidgets('five destinations fit a 320 px screen with large text', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester);
    for (final label in ['Habits', 'Communities', 'Notifications', 'Profile', 'Home']) {
      await tester.tap(find.byTooltip(label));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull, reason: 'switching to $label');
      }
      for (final target in ['Home', 'Habits', 'Communities', 'Notifications', 'Profile']) {
        final size = tester.getSize(find.byTooltip(target));
        expect(size.width, greaterThanOrEqualTo(48), reason: '$target touch target');
      }
    }
  });

  testWidgets('pages get the bar height as bottom inset', (tester) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(RootShellLayout));
    expect(find.text('inset a: ${BottomNavBar.obscuredHeight(context)}'), findsOneWidget);
  });
}
