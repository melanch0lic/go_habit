import 'package:flutter/material.dart';
import 'package:go_habit/feature/auth/view/components/auth_palette.dart';

/// Secondary link between the auth screens: "Don't have an account? **Sign up**".
class AuthNavigationButton extends StatelessWidget {
  /// Plain text before the action.
  final String text;

  /// Label of the tappable action.
  final String action;
  final VoidCallback? onPressed;

  const AuthNavigationButton({
    required this.text,
    required this.action,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.secondaryText)),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: palette.accent,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          child: Text(action),
        ),
      ],
    );
  }
}
