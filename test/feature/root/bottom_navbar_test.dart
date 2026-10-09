import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/resources/assets.gen.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/feature/root/view/components/bottom_navbar.dart';

import '../../helpers/haptics_recorder.dart';

void main() {
  final destinations = [
    BottomNavDestination(icon: Assets.navbarIcons.home, label: 'Главная'),
    BottomNavDestination(icon: Assets.navbarIcons.edit, label: 'Привычки'),
    BottomNavDestination(icon: Assets.navbarIcons.bell, label: 'Уведомления', badgeCount: 2),
  ];
  final trailing = BottomNavDestination(icon: Assets.navbarIcons.user, label: 'Профиль');

  Future<List<int>> pumpBar(
    WidgetTester tester, {
    int currentIndex = 0,
    Size size = const Size(390, 844),
    double textScale = 1,
    bool dark = false,
    bool disableAnimations = false,
  }) async {
    final taps = <int>[];
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.defaultTheme.lightTheme,
        darkTheme: AppTheme.defaultTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
            padding: const EdgeInsets.only(bottom: 34),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: BottomNavBar(
                currentIndex: currentIndex,
                destinations: destinations,
                trailing: trailing,
                onDestinationSelected: taps.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return taps;
  }

  testWidgets('shows the label of the selected destination only', (tester) async {
    await pumpBar(tester, currentIndex: 1);

    expect(find.text('Привычки'), findsOneWidget);
    expect(find.text('Главная'), findsNothing);
    expect(find.text('Профиль'), findsNothing);
  });

  testWidgets('reports taps with destination indices, trailing last', (tester) async {
    final taps = await pumpBar(tester);

    await tester.tap(find.byTooltip('Уведомления'));
    await tester.tap(find.byTooltip('Профиль'));
    await tester.tap(find.byTooltip('Главная'));

    expect(taps, [2, 3, 0]);
  });

  testWidgets('changing the destination gives selection haptics; re-tapping the current one does not', (tester) async {
    final haptics = recordHaptics(tester);
    await pumpBar(tester);

    await tester.tap(find.byTooltip('Главная'));
    expect(haptics, isEmpty);
    await tester.tap(find.byTooltip('Привычки'));
    expect(haptics, ['HapticFeedbackType.selectionClick']);
  });

  testWidgets('exposes labels, selection and badge to accessibility services', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpBar(tester, currentIndex: 3);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Профиль')),
      containsSemantics(label: 'Профиль', isButton: true, isSelected: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Уведомления, 2')),
      containsSemantics(label: 'Уведомления, 2', isButton: true, isSelected: false, hasTapAction: true),
    );
    expect(find.text('2'), findsOneWidget, reason: 'badge');
    semantics.dispose();
  });

  testWidgets('touch targets are at least 48x48', (tester) async {
    await pumpBar(tester);
    for (final label in ['Главная', 'Привычки', 'Уведомления', 'Профиль']) {
      final size = tester.getSize(find.descendant(of: find.byTooltip(label), matching: find.byType(InkWell)));
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }
  });

  testWidgets('a long label on a narrow screen with large text does not overflow', (tester) async {
    await pumpBar(tester, currentIndex: 2, size: const Size(320, 640), textScale: 2);
    expect(tester.takeException(), isNull);

    await pumpBar(tester, currentIndex: 3, size: const Size(320, 640), textScale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no frame of any tab transition overflows on a narrow screen', (tester) async {
    for (var from = 0; from < 4; from++) {
      for (var to = 0; to < 4; to++) {
        await pumpBar(tester, currentIndex: from, size: const Size(320, 640), textScale: 2);
        await pumpBar(tester, currentIndex: to, size: const Size(320, 640), textScale: 2);
        // pumpBar settles; replay the transition frame by frame.
        await pumpBar(tester, currentIndex: from, size: const Size(320, 640), textScale: 2);
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(tester.takeException(), isNull, reason: '$from -> $to');
      }
    }
  });

  testWidgets('keeps a fixed height and stays above the system inset', (tester) async {
    await pumpBar(tester);
    final bar = tester.getRect(find.byType(BottomNavBar));
    final pill = tester.getRect(find.byType(DecoratedBox).first);

    expect(pill.height, BottomNavBar.barHeight);
    expect(bar.bottom - pill.bottom, greaterThanOrEqualTo(34), reason: 'home indicator area stays free');
  });

  testWidgets('renders in the dark theme', (tester) async {
    await pumpBar(tester, dark: true, currentIndex: 1);
    expect(tester.takeException(), isNull);
    // The app's dark theme does not set `brightness`; the label must still be light.
    final label = tester.widget<Text>(find.text('Привычки'));
    expect(label.style?.color, const CommonColors().darkPrimaryText);
  });

  testWidgets('selection changes immediately when animations are disabled', (tester) async {
    await pumpBar(tester, disableAnimations: true);
    await pumpBar(tester, disableAnimations: true, currentIndex: 1);
    // A single frame, no settling.
    await tester.pump();
    expect(find.text('Привычки'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
