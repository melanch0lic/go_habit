import 'package:flutter/material.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/feature/auth/view/auth_validators.dart';
import 'package:go_habit/feature/auth/view/components/auth_palette.dart';

/// Password rules that tick off while the user types.
class PasswordRequirements extends StatelessWidget {
  final TextEditingController controller;

  const PasswordRequirements({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => Padding(
        padding: const EdgeInsets.only(left: 4, top: 8),
        child: Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _Requirement(label: l10n.password_req_length, met: AuthValidators.hasMinLength(value.text)),
            _Requirement(label: l10n.password_req_letters_digits, met: AuthValidators.hasLettersAndDigits(value.text)),
          ],
        ),
      ),
    );
  }
}

class _Requirement extends StatelessWidget {
  final String label;
  final bool met;

  const _Requirement({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final color = met ? palette.accent : palette.secondaryText;
    return Semantics(
      checked: met,
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(met ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: met ? palette.primaryText : palette.secondaryText),
            ),
          ),
        ],
      ),
    );
  }
}
