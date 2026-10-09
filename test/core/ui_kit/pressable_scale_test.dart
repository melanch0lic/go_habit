import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/ui_kit/app_haptics.dart';
import 'package:go_habit/core/ui_kit/pressable_scale.dart';

import '../../helpers/haptics_recorder.dart';

void main() {
  late int taps;
  late int longPresses;
  late ScrollController scroll;

  Future<void> pump(WidgetTester tester, {bool enabled = true, bool reduceMotion = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            body: ListView(
              controller: scroll,
              children: [
                Center(
                  child: PressableScale(
                    enabled: enabled,
                    child: GestureDetector(
                      onTap: () => taps++,
                      onLongPress: () => longPresses++,
                      child: const SizedBox(width: 120, height: 48, child: Text('button')),
                    ),
                  ),
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double scale(WidgetTester tester) => tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

  setUp(() {
    taps = 0;
    longPresses = 0;
    scroll = ScrollController();
  });

  tearDown(() => scroll.dispose());

  testWidgets('scales down while pressed and restores on release', (tester) async {
    await pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text('button')));
    await tester.pump();
    expect(scale(tester), 0.97);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(scale(tester), 1);
    expect(taps, 1);
  });

  testWidgets('restores when the gesture is cancelled, without tapping', (tester) async {
    await pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text('button')));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(scale(tester), 1);
    expect(taps, 0);
  });

  testWidgets('a drag releases the press and still scrolls the list', (tester) async {
    await pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text('button')));
    await tester.pump();
    // 40 px is past the touch slop: the gesture is now a scroll.
    for (var i = 0; i < 2; i++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
    }
    expect(scale(tester), 1, reason: 'released as soon as it becomes a scroll');
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
    }

    await gesture.up();
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(taps, 0);
  });

  testWidgets('each tap invokes the action exactly once, also when tapping rapidly', (tester) async {
    await pump(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('button'));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();
    expect(taps, 3);
  });

  testWidgets('does not interfere with long presses', (tester) async {
    await pump(tester);
    await tester.longPress(find.text('button'));
    await tester.pumpAndSettle();
    expect(longPresses, 1);
    expect(taps, 0);
    expect(scale(tester), 1);
  });

  testWidgets('shows no feedback when disabled', (tester) async {
    await pump(tester, enabled: false);
    final gesture = await tester.startGesture(tester.getCenter(find.text('button')));
    await tester.pump();
    expect(scale(tester), 1);
    await gesture.up();
  });

  testWidgets('a control disabled mid-press does not stay shrunk', (tester) async {
    await pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text('button')));
    await tester.pump();
    await pump(tester, enabled: false);
    await tester.pump();
    expect(scale(tester), 1);
    await gesture.up();
  });

  testWidgets('respects reduced motion', (tester) async {
    await pump(tester, reduceMotion: true);
    final gesture = await tester.startGesture(tester.getCenter(find.text('button')));
    await tester.pump();
    expect(scale(tester), 1);
    await gesture.up();
  });

  testWidgets('AppHaptics maps events to platform feedback types', (tester) async {
    final haptics = recordHaptics(tester);
    await AppHaptics.selection();
    await AppHaptics.success();
    expect(haptics, ['HapticFeedbackType.selectionClick', 'HapticFeedbackType.lightImpact']);
  });
}
