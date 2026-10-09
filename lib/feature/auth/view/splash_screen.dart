import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/feature/auth/domain/bloc/auth_bloc.dart';
import 'package:go_habit/feature/auth/view/welcome_screen.dart';
import 'package:go_router/go_router.dart';

/// Shows the welcome animation, then opens the app or the sign-in screen.
///
/// The stored session is restored by `Supabase.initialize` before the app starts, so
/// the decision never waits for the network and the sign-in screen does not flash for
/// signed-in users.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Length of the welcome animation.
  static const displayDuration = Duration(milliseconds: 2500);

  /// With reduced motion the animation is skipped, so only a short pause remains.
  static const reducedMotionDuration = Duration(milliseconds: 600);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer ??= Timer(
      MediaQuery.disableAnimationsOf(context) ? SplashScreen.reducedMotionDuration : SplashScreen.displayDuration,
      _proceed,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _proceed() {
    if (!mounted) return;
    // The router redirect has the final say, e.g. if the session ended meanwhile.
    final signedIn = context.read<AuthBloc>().state is AuthUserAuthenticated;
    context.go(signedIn ? HomeRoutes.home.path : AuthRoutes.login.path);
  }

  @override
  Widget build(BuildContext context) => const WelcomeScreen();
}
