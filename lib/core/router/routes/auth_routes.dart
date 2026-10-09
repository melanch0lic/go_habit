part of '../app_router.dart';

final _authRoutes = [
  GoRoute(
    path: AuthRoutes.login.path,
    name: AuthRoutes.login.name,
    builder: (_, state) => AuthScreen(key: state.pageKey),
  ),
  GoRoute(
    path: AuthRoutes.register.path,
    name: AuthRoutes.register.name,
    builder: (_, state) => RegistrationScreen(key: state.pageKey),
  ),
  GoRoute(
    path: AuthRoutes.forgotPassword.path,
    name: AuthRoutes.forgotPassword.name,
    builder: (_, state) => ForgotPasswordScreen(
      key: state.pageKey,
      initialEmail: state.extra is String ? state.extra! as String : '',
    ),
  ),
  GoRoute(
    path: AuthRoutes.resetPassword.path,
    name: AuthRoutes.resetPassword.name,
    builder: (_, state) => ResetPasswordScreen(key: state.pageKey),
  ),
  GoRoute(
    path: AuthRoutes.welcome.path,
    name: AuthRoutes.welcome.name,
    builder: (_, state) => WelcomeScreen(key: state.pageKey),
  ),
];
