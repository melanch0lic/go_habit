import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/ui_kit/app_haptics.dart';
import 'package:go_habit/core/ui_kit/pressable_scale.dart';
import 'package:go_habit/feature/habit_stats/bloc/habit_stats_bloc.dart';

/// Marks a habit as done for today, or undoes today's mark.
///
/// A tap shows the requested state at once and asks [HabitStatsBloc] for exactly that
/// state, so a repeated tap cannot flip the mark back. Taps are ignored until the
/// result arrives. The "done" haptic follows the confirmed state; if saving fails, the
/// control returns to the stored state (the screen explains the failure). A completion
/// arriving from synchronization updates the control silently.
class HabitCompletionButton extends StatefulWidget {
  final String habitId;

  /// Background while the habit is not done today.
  final Color color;

  /// Background once the habit is done today.
  final Color completedColor;
  final Color iconColor;

  /// A round check control (habits list) instead of the square toggle (home cards).
  final bool round;

  /// Diameter of the round control; also its touch target.
  final double size;

  const HabitCompletionButton({
    required this.habitId,
    required this.color,
    required this.iconColor,
    this.completedColor = Colors.grey,
    this.round = false,
    this.size = 48,
    super.key,
  });

  @override
  State<HabitCompletionButton> createState() => _HabitCompletionButtonState();
}

class _HabitCompletionButtonState extends State<HabitCompletionButton> {
  /// The state requested by the last tap, shown until the bloc confirms or fails.
  bool? _pending;
  Timer? _pendingTimeout;

  static const _duration = Duration(milliseconds: 180);
  static const _resultTimeout = Duration(seconds: 3);

  bool _isCompleted(HabitStatsState state) => state is HabitStatsLoaded && state.isCompletedToday(widget.habitId);

  void _onTap(bool shown) {
    if (_pending != null) return; // a request is still running
    final target = !shown;
    setState(() => _pending = target);
    _pendingTimeout?.cancel();
    _pendingTimeout = Timer(_resultTimeout, () {
      if (mounted) setState(() => _pending = null);
    });
    context.read<HabitStatsBloc>().add(HabitCompletionToggled(widget.habitId, completed: target));
  }

  void _onStateChanged(BuildContext context, HabitStatsState state) {
    final pending = _pending;
    if (pending == null) return;
    final failed = state is HabitStatsLoaded && state.failedHabitId == widget.habitId;
    final confirmed = _isCompleted(state) == pending;
    if (!failed && !confirmed) return;
    _pendingTimeout?.cancel();
    setState(() => _pending = null);
    if (confirmed && pending) AppHaptics.success();
  }

  @override
  void dispose() {
    _pendingTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stored = context.select<HabitStatsBloc, bool>((bloc) => _isCompleted(bloc.state));
    final completed = _pending ?? stored;
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : _duration;

    return BlocListener<HabitStatsBloc, HabitStatsState>(
      listener: _onStateChanged,
      child: Semantics(
        button: true,
        toggled: completed,
        label: completed ? context.l10n.habit_unmark_done : context.l10n.habit_mark_done,
        excludeSemantics: true,
        onTap: () => _onTap(completed),
        child: PressableScale(
          pressedScale: 0.92,
          child: widget.round ? _round(completed, duration) : _square(completed, duration),
        ),
      ),
    );
  }

  Widget _icon(bool completed, Duration duration, {required IconData done, required IconData notDone, double? size}) =>
      AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(completed ? done : notDone, key: ValueKey(completed), color: widget.iconColor, size: size),
      );

  Widget _square(bool completed, Duration duration) => InkWell(
        onTap: () => _onTap(completed),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: completed ? widget.completedColor : widget.color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: _icon(completed, duration, done: Icons.close, notDone: Icons.check),
        ),
      );

  Widget _round(bool completed, Duration duration) => Material(
        type: MaterialType.transparency,
        child: InkResponse(
          onTap: () => _onTap(completed),
          radius: widget.size / 2,
          child: SizedBox.square(
            dimension: widget.size,
            child: Center(
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOut,
                width: widget.size - 12,
                height: widget.size - 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: completed ? widget.completedColor : Colors.transparent,
                  border: Border.all(color: completed ? widget.completedColor : widget.color, width: 2),
                ),
                child: completed
                    ? _icon(completed, duration, done: Icons.check, notDone: Icons.check, size: 20)
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
}
