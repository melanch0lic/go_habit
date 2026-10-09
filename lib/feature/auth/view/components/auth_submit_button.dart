import 'package:flutter/material.dart';
import 'package:go_habit/core/ui_kit/pressable_scale.dart';
import 'package:go_habit/feature/auth/view/components/auth_palette.dart';

/// The primary action of an auth screen. While [loading] it shows a progress
/// indicator, keeps its size and ignores taps.
class AuthSubmitButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const AuthSubmitButton({required this.label, required this.onPressed, this.loading = false, super.key});

  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final enabled = !loading && onPressed != null;

    return Semantics(
      // The label stays in the tree while loading, but the state is announced.
      liveRegion: loading,
      child: PressableScale(
        enabled: enabled,
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(height),
            maximumSize: const Size.fromHeight(height),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            // A running request keeps the brand color instead of the grey disabled look.
            disabledBackgroundColor: loading ? palette.accent.withValues(alpha: 0.75) : null,
            disabledForegroundColor: loading ? Colors.white : null,
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: loading ? 0 : 1,
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (loading)
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
