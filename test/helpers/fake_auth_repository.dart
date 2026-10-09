import 'dart:async';

import 'package:go_habit/core/sync/sync_service.dart';
import 'package:go_habit/feature/auth/domain/models/auth_failure.dart';
import 'package:go_habit/feature/auth/domain/repositories/i_authentication_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final testUser = User(id: 'u1', appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: '');

/// Records calls; each operation can be made to fail or to wait for [gate].
class FakeAuthRepository implements IAuthenticationRepository {
  final users = StreamController<User?>.broadcast();
  final log = <String>[];
  User? signedIn;

  /// Thrown (as [AuthFailureException]) by the next operations, if set.
  AuthFailure? failure;

  /// Operations wait for this completer, if set, to observe the loading state.
  Completer<void>? gate;

  SignUpResult signUpResult = SignUpResult.confirmationRequired;

  /// Calls of backend operations (not counting the session stream).
  int get requestCount => log.where((entry) => entry != 'signOut').length;

  FakeAuthRepository({this.signedIn});

  Future<void> _request(String name) async {
    log.add(name);
    await gate?.future;
    if (failure case final failure?) throw AuthFailureException(failure);
  }

  @override
  Stream<User?> getCurrentUser() => users.stream;

  @override
  User? getSignedInUser() => signedIn;

  @override
  Future<void> signInWithEmail({required String email, required String password}) async {
    await _request('signIn:$email');
    signedIn = testUser;
    users.add(testUser);
  }

  @override
  Future<SignUpResult> signUp({required String email, required String password}) async {
    await _request('signUp:$email');
    if (signUpResult == SignUpResult.signedIn) {
      signedIn = testUser;
      users.add(testUser);
    }
    return signUpResult;
  }

  @override
  Future<void> resendSignUpConfirmation({required String email}) => _request('resend:$email');

  @override
  Future<void> requestPasswordReset({required String email}) => _request('reset:$email');

  @override
  Future<void> updatePassword({required String password}) => _request('updatePassword');

  @override
  Future<void> signOut() async {
    log.add('signOut');
    signedIn = null;
    users.add(null);
  }

  Future<void> dispose() => users.close();
}

class FakeSessionData implements SessionDataManager {
  final List<String> log;
  int pending;

  FakeSessionData(this.log, {this.pending = 0});

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
