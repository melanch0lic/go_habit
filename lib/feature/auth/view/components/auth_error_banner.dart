import 'package:flutter/material.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/feature/auth/domain/models/auth_failure.dart';
import 'package:go_habit/feature/auth/view/auth_validators.dart';
import 'package:go_habit/feature/auth/view/components/auth_palette.dart';

/// Explains a failed request above the primary button; takes no space without one.
class AuthErrorBanner extends StatelessWidget {
  final AuthFailure? failure;

  const AuthErrorBanner({required this.failure, super.key});

  static const _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final failure = this.failure;
    final palette = AuthPalette.of(context);

    final content = failure == null
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Semantics(
              liveRegion: true,
              container: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.error.withValues(alpha: palette.isDark ? 0.14 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.error.withValues(alpha: 0.35)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, size: 20, color: palette.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          failure.message(context.l10n),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: palette.primaryText, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

    // AnimatedSize does not support a zero duration.
    if (MediaQuery.disableAnimationsOf(context)) return content;
    return AnimatedSize(
      duration: _duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: content,
    );
  }
}
