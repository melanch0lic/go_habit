import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/ui_kit/app_haptics.dart';
import 'package:go_habit/core/ui_kit/pressable_scale.dart';
import 'package:go_habit/feature/habit_stats/bloc/habit_stats_bloc.dart';

/// Marks a habit as done for today, or undoes today's mark.
///
/// Press feedback is immediate; the "done" feedback (haptic and icon transition)
/// follows the confirmed state from [HabitStatsBloc], so it never claims success
/// for a write that did not happen. A completion arriving from synchronization
/// updates the icon silently.
class HabitCompletionButton extends StatefulWidget {
  final String habitId;

  /// Background while the habit is not done today.
  final Color color;

  /// Background once the habit is done today.
  final Color completedColor;
  final Color iconColor;

  const HabitCompletionButton({
    required this.habitId,
    required this.color,
    required this.iconColor,
    this.completedColor = Colors.grey,
    super.key,
  });

  @override
  State<HabitCompletionButton> createState() => _HabitCompletionButtonState();
}

class _HabitCompletionButtonState extends State<HabitCompletionButton> {
  /// Set by a tap and consumed by the resulting state change.
  bool _awaitingResult = false;
  Timer? _awaitTimeout;

  static const _duration = Duration(milliseconds: 180);
  static const _resultTimeout = Duration(seconds: 3);

  bool _isCompleted(HabitStatsState state) => state is HabitStatsLoaded && state.isCompletedToday(widget.habitId);

  void _onTap() {
    _awaitingResult = true;
    _awaitTimeout?.cancel();
    _awaitTimeout = Timer(_resultTimeout, () => _awaitingResult = false);
    context.read<HabitStatsBloc>().add(HabitCompletionToggled(widget.habitId));
  }

  void _onCompletionChanged(BuildContext context, HabitStatsState state) {
    if (!_awaitingResult) return;
    _awaitingResult = false;
    _awaitTimeout?.cancel();
    if (_isCompleted(state)) AppHaptics.success();
  }

  @override
  void dispose() {
    _awaitTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completed = context.select<HabitStatsBloc, bool>((bloc) => _isCompleted(bloc.state));
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : _duration;

    return BlocListener<HabitStatsBloc, HabitStatsState>(
      listenWhen: (previous, current) => _isCompleted(previous) != _isCompleted(current),
      listener: _onCompletionChanged,
      child: Semantics(
        button: true,
        label: completed ? context.l10n.habit_unmark_done : context.l10n.habit_mark_done,
        excludeSemantics: true,
        onTap: _onTap,
        child: PressableScale(
          pressedScale: 0.92,
          child: InkWell(
            onTap: _onTap,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: completed ? widget.completedColor : widget.color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: AnimatedSwitcher(
                duration: duration,
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  completed ? Icons.close : Icons.check,
                  key: ValueKey(completed),
                  color: widget.iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
