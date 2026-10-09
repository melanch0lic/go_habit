import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/feature/auth/domain/bloc/auth_bloc.dart' as app_auth;
import 'package:go_habit/feature/auth/domain/bloc/auth_bloc.dart';
import 'package:go_habit/feature/auth/domain/repositories/i_authentication_repository.dart';
import 'package:go_habit/feature/initizialization/scopes/app_scope_container.dart';
import 'package:yx_scope_flutter/yx_scope_flutter.dart';

class AuthScope extends StatelessWidget {
  final Widget child;

  const AuthScope({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return ScopeBuilder<AppScopeContainer>.withPlaceholder(builder: (context, scope) {
      // The repository is also provided directly: each auth screen creates its own
      // AuthFormBloc with it.
      return RepositoryProvider<IAuthenticationRepository>.value(
        value: scope.authRepositoryDep.get,
        child: BlocProvider<app_auth.AuthBloc>(
          // Created eagerly so the session check is done before the splash ends.
          lazy: false,
          create: (context) => app_auth.AuthBloc(
            scope.authRepositoryDep.get,
            scope.syncService.get,
          )..add(AuthInitialCheckRequested()),
          child: child,
        ),
      );
    });
  }
}
