import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/feature/auth/domain/bloc/auth_bloc.dart';
import 'package:go_habit/feature/initizialization/scopes/app_scope_container.dart';
import 'package:go_habit/feature/social/bloc/friends_bloc.dart';
import 'package:go_habit/feature/social/bloc/my_profile_bloc.dart';
import 'package:yx_scope_flutter/yx_scope_flutter.dart';

/// Provides the signed-in user's profile and friends to every route (tabs and
/// full-screen pages). The blocs follow the session: they reload for a newly signed-in
/// user and are cleared on sign-out, without rebuilding the navigation below.
class SocialScope extends StatelessWidget {
  final Widget child;

  const SocialScope({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return ScopeBuilder<AppScopeContainer>.withPlaceholder(
      builder: (context, scope) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => MyProfileBloc(scope.socialRepository.get)),
          BlocProvider(create: (_) => FriendsBloc(scope.socialRepository.get)),
        ],
        child: _SessionSync(child: child),
      ),
    );
  }
}

class _SessionSync extends StatefulWidget {
  final Widget child;

  const _SessionSync({required this.child});

  @override
  State<_SessionSync> createState() => _SessionSyncState();
}

class _SessionSyncState extends State<_SessionSync> {
  String? _userId;

  @override
  void initState() {
    super.initState();
    _apply(context.read<AuthBloc>().state);
  }

  void _apply(AuthState state) {
    final userId = state is AuthUserAuthenticated ? state.user.id : null;
    if (userId == _userId) return;
    _userId = userId;
    final profile = context.read<MyProfileBloc>();
    final friends = context.read<FriendsBloc>();
    if (userId == null) {
      profile.add(const MyProfileReset());
      friends.add(const FriendsReset());
    } else {
      profile.add(const MyProfileRequested());
      friends.add(const FriendsRequested());
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<AuthBloc, AuthState>(
        // Errors and confirmation prompts keep the session; only user changes matter.
        listenWhen: (previous, current) => current is AuthUserAuthenticated || current is AuthUserUnauthenticated,
        listener: (context, state) => _apply(state),
        child: widget.child,
      );
}
