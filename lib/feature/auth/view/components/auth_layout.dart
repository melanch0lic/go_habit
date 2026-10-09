import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_habit/feature/auth/view/components/auth_palette.dart';

/// Common frame of the auth screens: the brand mark, a heading, supporting text and
/// the screen's content, centered and scrollable so the keyboard never covers it.
class AuthLayout extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  /// Replaces the brand mark, e.g. with a status icon.
  final Widget? leading;

  const AuthLayout({required this.title, required this.child, this.subtitle, this.leading, super.key});

  static const double _maxContentWidth = 420;
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(24, 16, 24, 24);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AuthPalette.of(context);
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      appBar: canPop
          ? AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: _padding,
            child: ConstrainedBox(
              // Centers short content vertically; longer content (small phones, open
              // keyboard, large text) simply scrolls.
              constraints: BoxConstraints(minHeight: math.max(0, constraints.maxHeight - _padding.vertical)),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: leading ?? const AuthBrandMark()),
                      const SizedBox(height: 24),
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: palette.primaryText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (subtitle case final subtitle?) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: palette.secondaryText, height: 1.4),
                        ),
                      ],
                      const SizedBox(height: 32),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small habit grid, echoing the contribution chart of the welcome screen.
class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key});

  static const _neutral = Color.fromARGB(255, 33, 43, 39);

  // Completion intensity per day, two weeks; the latest day is fully green.
  static const _levels = [
    [0.0, 0.35, 0.0, 0.6, 0.35, 0.0, 0.6],
    [0.35, 0.6, 0.0, 0.85, 0.6, 0.85, 1.0],
  ];

  @override
  Widget build(BuildContext context) {
    final accent = AuthPalette.of(context).accent;
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (row, levels) in _levels.indexed) ...[
              if (row > 0) const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (column, level) in levels.indexed) ...[
                    if (column > 0) const SizedBox(width: 3),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color.lerp(_neutral, accent, level),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const SizedBox.square(dimension: 12),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A round tinted icon used instead of the brand mark for status screens.
class AuthStatusIcon extends StatelessWidget {
  final IconData icon;

  const AuthStatusIcon(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.accent.withValues(alpha: palette.isDark ? 0.2 : 0.12),
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Icon(icon, size: 36, color: palette.accent),
        ),
      ),
    );
  }
}

/// Cross-fades between a form and its result; instant with reduced motion.
class AuthFadeSwitcher extends StatelessWidget {
  final Widget child;

  const AuthFadeSwitcher({required this.child, super.key});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: child,
      );
}
