import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Scales [child] down slightly while a pointer is pressed on it.
///
/// Purely visual: it observes pointers with a [Listener] instead of joining the
/// gesture arena, so it never triggers, delays or swallows the child's own taps,
/// long presses, drags or scrolling. The press is released when the pointer lifts,
/// is cancelled, or moves far enough to become a scroll or drag.
class PressableScale extends StatefulWidget {
  final Widget child;

  /// Set to false for disabled or loading controls: no feedback is shown.
  final bool enabled;

  /// Scale while pressed.
  final double pressedScale;

  const PressableScale({
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.97,
    super.key,
  });

  static const duration = Duration(milliseconds: 120);

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  int? _pointer;
  Offset _downPosition = Offset.zero;

  bool get _pressed => _pointer != null;

  void _onDown(PointerDownEvent event) {
    if (!widget.enabled || _pressed) return;
    setState(() {
      _pointer = event.pointer;
      _downPosition = event.position;
    });
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer == _pointer && (event.position - _downPosition).distance > kTouchSlop) _release();
  }

  void _onEnd(PointerEvent event) {
    if (event.pointer == _pointer) _release();
  }

  void _release() => setState(() => _pointer = null);

  @override
  void didUpdateWidget(PressableScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A control disabled mid-press (e.g. it started loading) must not stay shrunk.
    if (!widget.enabled && _pressed) _pointer = null;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onEnd,
      onPointerCancel: _onEnd,
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? widget.pressedScale : 1,
        duration: reduceMotion ? Duration.zero : PressableScale.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
