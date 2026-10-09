import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/sync/sync_service.dart';
import 'package:go_habit/feature/auth/domain/bloc/auth_bloc.dart';
import 'package:go_habit/feature/auth/domain/repositories/i_authentication_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _user = User(id: 'u1', appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: '');

class _FakeAuthRepository implements IAuthenticationRepository {
  final users = StreamController<User?>.broadcast();
  final log = <String>[];
  User? signedIn = _user;
  bool failRemoteSignOut = false;

  @override
  Stream<User?> getCurrentUser() => users.stream;

  @override
  User? getSignedInUser() => signedIn;

  @override
  Future<void> signInWithEmail({required String email, required String password}) async {}

  @override
  Future<void> signUp({required String email, required String password}) async {}

  @override
  Future<void> signOut() async {
    log.add('signOut');
    signedIn = null;
    users.add(null);
    if (failRemoteSignOut) throw Exception('network');
  }
}

class _FakeSessionData implements SessionDataManager {
  final List<String> log;
  int pending;

  _FakeSessionData(this.log, {this.pending = 0});

  @override
  Future<bool> syncNow() async {
    log.add('sync');
    return pending == 0;
  }

  @override
  Future<int> pendingChangesCount() async => pending;

  @override
  Future<void> clearLocalData() async => log.add('clear');
}

void main() {
  late _FakeAuthRepository repository;
  late _FakeSessionData session;
  late AuthBloc bloc;

  Future<void> signedInBloc({int pending = 0}) async {
    repository = _FakeAuthRepository();
    session = _FakeSessionData(repository.log, pending: pending);
    bloc = AuthBloc(repository, session)..add(AuthInitialCheckRequested());
    await pumpEventQueue();
    expect(bloc.state, isA<AuthUserAuthenticated>());
  }

  tearDown(() => bloc.close());

  test('restores an existing session on start', () async {
    await signedInBloc();
    expect((bloc.state as AuthUserAuthenticated).user.id, 'u1');
  });

  test('logout syncs first, signs out, then wipes local data', () async {
    await signedInBloc();
    bloc.add(AuthLogoutButtonPressed());
    await pumpEventQueue();

    expect(repository.log, ['sync', 'signOut', 'clear']);
    expect(bloc.state, isA<AuthUserUnauthenticated>());
  });

  test('logout with unsynced changes asks for confirmation and keeps everything', () async {
    await signedInBloc(pending: 3);
    bloc.add(AuthLogoutButtonPressed());
    await pumpEventQueue();

    expect(bloc.state, isA<AuthLogoutConfirmationRequired>().having((s) => s.pendingChanges, 'pending', 3));
    expect(repository.log, ['sync']);
  });

  test('confirmed logout discards unsynced changes', () async {
    await signedInBloc(pending: 3);
    bloc.add(AuthLogoutButtonPressed(force: true));
    await pumpEventQueue();

    expect(repository.log, ['signOut', 'clear']);
    expect(bloc.state, isA<AuthUserUnauthenticated>());
  });

  test('local data is wiped even if revoking the session on the server fails', () async {
    await signedInBloc();
    repository.failRemoteSignOut = true;
    bloc.add(AuthLogoutButtonPressed());
    await pumpEventQueue();

    expect(repository.log, ['sync', 'signOut', 'clear']);
  });

  test('a session that ends elsewhere (e.g. expired) moves to unauthenticated', () async {
    await signedInBloc();
    repository.users.add(null);
    await pumpEventQueue();
    expect(bloc.state, isA<AuthUserUnauthenticated>());
  });
}
