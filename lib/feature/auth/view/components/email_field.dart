import 'package:flutter/material.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/feature/auth/view/auth_validators.dart';
import 'package:go_habit/feature/auth/view/components/auth_text_field.dart';

class EmailFieldWidget extends StatelessWidget {
  const EmailFieldWidget({
    required TextEditingController emailController,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.onChanged,
    this.enabled = true,
    super.key,
  }) : _emailController = emailController;

  final TextEditingController _emailController;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthTextField(
      controller: _emailController,
      focusNode: focusNode,
      label: l10n.email_label,
      hint: l10n.email_hint,
      prefixIcon: Icons.mail_outline,
      keyboardType: TextInputType.emailAddress,
      textInputAction: textInputAction,
      autofillHints: const [AutofillHints.email],
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      enabled: enabled,
      validator: (value) => AuthValidators.email(value, l10n),
    );
  }
}
