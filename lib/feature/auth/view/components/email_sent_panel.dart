import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/feature/auth/view/components/auth_palette.dart';
import 'package:go_habit/feature/auth/view/components/auth_submit_button.dart';

/// Next steps after an email was sent: a message, a hint, a resend action with a
/// cooldown and a way back to sign-in.
class EmailSentPanel extends StatefulWidget {
  final String message;
  final String hint;
  final VoidCallback onResend;
  final bool resending;
  final VoidCallback onBackToSignIn;

  const EmailSentPanel({
    required this.message,
    required this.hint,
    required this.onResend,
    required this.onBackToSignIn,
    this.resending = false,
    super.key,
  });

  /// Supabase limits how often emails are sent; waiting avoids pointless failures.
  static const resendCooldown = Duration(seconds: 60);

  @override
  State<EmailSentPanel> createState() => _EmailSentPanelState();
}

class _EmailSentPanelState extends State<EmailSentPanel> {
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    _secondsLeft = EmailSentPanel.resendCooldown.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  void _resend() {
    widget.onResend();
    setState(_startCooldown);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = AuthPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final canResend = _secondsLeft <= 0 && !widget.resending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.message,
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(color: palette.primaryText, height: 1.4),
        ),
        const SizedBox(height: 12),
        Text(
          widget.hint,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: palette.secondaryText, height: 1.4),
        ),
        const SizedBox(height: 32),
        AuthSubmitButton(label: l10n.auth_back_to_sign_in, onPressed: widget.onBackToSignIn),
        const SizedBox(height: 8),
        TextButton(
          onPressed: canResend ? _resend : null,
          style: TextButton.styleFrom(
            foregroundColor: palette.accent,
            minimumSize: const Size.fromHeight(48),
          ),
          child: Text(
            _secondsLeft > 0 ? l10n.auth_resend_in(_secondsLeft) : l10n.auth_resend_email,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
