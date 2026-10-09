import 'package:flutter/material.dart';
import 'package:go_habit/core/extension/theme_extension.dart';

/// Colors of the auth screens, taken from the app's `CommonColors`.
///
/// The app's dark [ThemeData] does not set `brightness`, so the card color tells the
/// themes apart (the same approach as the bottom navigation bar).
@immutable
class AuthPalette {
  final bool isDark;
  final Color accent;
  final Color surface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final Color error;

  const AuthPalette._({
    required this.isDark,
    required this.accent,
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.error,
  });

  factory AuthPalette.of(BuildContext context) {
    final theme = context.themeOf;
    final colors = context.theme.commonColors;
    final isDark = theme.cardColor.computeLuminance() < 0.5;
    return AuthPalette._(
      isDark: isDark,
      accent: colors.green100,
      surface: theme.cardColor,
      border: isDark ? colors.darkDivider : colors.neutralgrey10,
      primaryText: isDark ? colors.darkPrimaryText : colors.lightPrimaryText,
      secondaryText: isDark ? colors.darkSecondaryText : colors.lightSecondaryText,
      // The app signals errors in red (snack bars, sign-out); these shades keep 4.5:1
      // contrast on the respective surfaces.
      error: isDark ? Colors.red.shade300 : Colors.red.shade700,
    );
  }
}
