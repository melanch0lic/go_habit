import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/feature/social/bloc/friends_bloc.dart';
import 'package:go_habit/feature/social/bloc/friends_leaderboard_bloc.dart';
import 'package:go_habit/feature/social/bloc/my_profile_bloc.dart';
import 'package:go_habit/feature/social/bloc/profile_edit_bloc.dart';
import 'package:go_habit/feature/social/bloc/public_profile_bloc.dart';
import 'package:go_habit/feature/social/domain/friend_action.dart';
import 'package:go_habit/feature/social/domain/models/social.dart';

import 'social_fakes.dart';

void main() {
  late FakeSocialServer server;
  late FakeSocialRepository alice;
  late FakeSocialRepository bob;

  setUp(() {
    server = FakeSocialServer()
      ..addUser('alice', nickname: 'Alice_1', weekCompleted: 5, weekEligible: 5)
      ..addUser('bob', weekCompleted: 1, weekEligible: 5)
      ..addUser('carol', nickname: 'Carol', weekEligible: 5);
    alice = FakeSocialRepository(server, 'alice');
    bob = FakeSocialRepository(server, 'bob');
  });

  tearDown(() async {
    await alice.dispose();
    await bob.dispose();
  });

  group('MyProfileBloc', () {
    test('loads the profile and knows when a nickname is missing', () async {
      final bloc = MyProfileBloc(bob)..add(const MyProfileRequested());
      await pumpEventQueue();
      expect(bloc.state.status, MyProfileStatus.ready);
      expect(bloc.state.needsNickname, isTrue);
      await bloc.close();
    });

    test('signing out cancels a load in flight, so the old account never reappears', () async {
      final bloc = MyProfileBloc(alice);
      alice.gate = Completer<void>();
      bloc.add(const MyProfileRequested());
      await pumpEventQueue();
      bloc.add(const MyProfileReset());
      alice.gate!.complete();
      await pumpEventQueue();
      expect(bloc.state.profile, isNull);
      await bloc.close();
    });

    test('a failed privacy change keeps the old setting and reports it', () async {
      final bloc = MyProfileBloc(alice)..add(const MyProfileRequested());
      await pumpEventQueue();
      alice.failures['privacy'] = SocialFailure.offline;
      bloc.add(const MyPrivacyChanged(stats: ProfileVisibility.everyone, communities: ProfileVisibility.nobody));
      final failure = await bloc.stream.firstWhere((s) => s.privacyFailure != null);
      expect(failure.privacyFailure, SocialFailure.offline);
      expect(bloc.state.profile!.statsVisibility, ProfileVisibility.friends);
      await bloc.close();
    });
  });

  group('ProfileEditBloc', () {
    ProfileEditBloc edit(FakeSocialRepository repository, {MyProfile? profile}) =>
        ProfileEditBloc(repository, profile: profile, debounce: Duration.zero);

    test('checks availability for the latest value only (debounced, case-insensitive)', () async {
      final bloc = edit(bob)
        ..add(const NicknameEdited('Ali'))
        ..add(const NicknameEdited('ALICE_1'));
      await pumpEventQueue();
      expect(bloc.state.check, NicknameCheck.taken);
      expect(bob.log.where((e) => e.startsWith('status')), ['status:ALICE_1'],
          reason: 'the earlier check was cancelled');
      expect(bloc.state.canSave, isFalse);

      bloc.add(const NicknameEdited('Bob'));
      await pumpEventQueue();
      expect(bloc.state.check, NicknameCheck.available);
      expect(bloc.state.canSave, isTrue);
      await bloc.close();
    });

    test('invalid input is explained locally without a request', () async {
      final bloc = edit(bob)..add(const NicknameEdited('1x'));
      await pumpEventQueue();
      expect(bloc.state.check, NicknameCheck.invalid);
      expect(bob.log, isEmpty);
      await bloc.close();
    });

    test('the own current nickname is not checked again', () async {
      final bloc = edit(alice, profile: server.profileOf('alice'))..add(const NicknameEdited('alice_1'));
      await pumpEventQueue();
      expect(bloc.state.check, NicknameCheck.unchanged);
      expect(alice.log, isEmpty);
      await bloc.close();
    });

    test('a nickname claimed meanwhile by someone else fails on save and is marked taken', () async {
      final bloc = edit(bob)..add(const NicknameEdited('Dave'));
      await pumpEventQueue();
      expect(bloc.state.check, NicknameCheck.available);

      // Carol takes it between the check and the save.
      server.updateProfile('carol', nickname: 'dave');
      bloc.add(const ProfileEditSubmitted(bio: ''));
      final failed = await bloc.stream.firstWhere((s) => s.failure != null);
      expect(failed.failure, SocialFailure.nicknameTaken);
      expect(bloc.state.check, NicknameCheck.taken);
      expect(bloc.state.saved, isNull);
      await bloc.close();
    });

    test('a second tap while saving does not send a second request', () async {
      final bloc = edit(bob)..add(const NicknameEdited('Bob'));
      await pumpEventQueue();
      bob.gate = Completer<void>();
      bloc
        ..add(const ProfileEditSubmitted(bio: 'hi'))
        ..add(const ProfileEditSubmitted(bio: 'hi'));
      await pumpEventQueue();
      bob.gate!.complete();
      final saved = await bloc.stream.firstWhere((s) => s.saved != null);
      expect(saved.saved!.nickname, 'Bob');
      expect(bob.log.where((e) => e.startsWith('update')), hasLength(1));
      await bloc.close();
    });
  });

  group('FriendsBloc', () {
    test('search, request, and the result shows the new relationship', () async {
      final bloc = FriendsBloc(bob)..add(const FriendsRequested());
      await pumpEventQueue();
      bloc.add(const FriendSearchSubmitted(' alice_1 '));
      await pumpEventQueue();
      final result = bloc.state.search.results.single;
      expect(result.relationship, Relationship.none);

      final notices = <SocialNotice>[];
      bloc.stream.listen((s) => s.notice == null ? null : notices.add(s.notice!));
      bloc.add(FriendActionRequested(FriendAction.send, result.user.publicId));
      await pumpEventQueue();
      expect(bloc.state.search.results.single.relationship, Relationship.outgoing);
      expect(bloc.state.graph.outgoing, hasLength(1), reason: 'the list reloads after a confirmed change');
      expect(notices.single.relationship, Relationship.outgoing, reason: 'shown once');
      await bloc.close();
    });

    test('repeated taps on one user send one request', () async {
      final bloc = FriendsBloc(bob);
      bob.gate = Completer<void>();
      final id = server.publicIdOf('alice');
      bloc
        ..add(FriendActionRequested(FriendAction.send, id))
        ..add(FriendActionRequested(FriendAction.send, id));
      await pumpEventQueue();
      expect(bloc.state.busy, {id});
      bob.gate!.complete();
      await pumpEventQueue();
      expect(bob.log.where((e) => e.startsWith('send')), hasLength(1));
      expect(bloc.state.busy, isEmpty);
      await bloc.close();
    });

    test('an offline action is reported and nothing changes', () async {
      final bloc = FriendsBloc(bob);
      bob.online = false;
      bloc.add(FriendActionRequested(FriendAction.send, server.publicIdOf('alice')));
      final failed = await bloc.stream.firstWhere((s) => s.notice != null);
      expect(failed.notice!.failure, SocialFailure.offline);
      expect(server.pairCount, 0);
      await bloc.close();
    });

    test('load failure, retry, and reset on sign-out', () async {
      bob.failures['graph'] = SocialFailure.network;
      final bloc = FriendsBloc(bob)..add(const FriendsRequested());
      await pumpEventQueue();
      expect(bloc.state.status, LoadState.failure);

      bob.failures.clear();
      bloc.add(const FriendsRequested());
      await pumpEventQueue();
      expect(bloc.state.status, LoadState.ready);

      bloc.add(const FriendsReset());
      await pumpEventQueue();
      expect(bloc.state.status, LoadState.initial);
      expect(bloc.state.graph.connections, isEmpty);
      await bloc.close();
    });
  });

  group('PublicProfileBloc', () {
    test('accepting updates the relationship and reveals friends-only statistics', () async {
      await bob.sendRequest(server.publicIdOf('alice'));
      final bloc = PublicProfileBloc(alice, publicId: server.publicIdOf('bob'))..add(const PublicProfileRequested());
      await pumpEventQueue();
      expect(bloc.state.profile!.relationship, Relationship.incoming);
      expect(bloc.state.profile!.statsVisible, isFalse);

      bloc.add(const PublicProfileActionRequested(FriendAction.accept));
      await pumpEventQueue();
      expect(bloc.state.profile!.relationship, Relationship.friends);
      expect(bloc.state.profile!.statsVisible, isTrue);
      await bloc.close();
    });

    test('a profile hidden by a block reads as not found', () async {
      await alice.block(server.publicIdOf('bob'));
      final bloc = PublicProfileBloc(bob, publicId: server.publicIdOf('alice'))..add(const PublicProfileRequested());
      await pumpEventQueue();
      expect(bloc.state.status, PublicProfileStatus.failure);
      expect(bloc.state.failure, SocialFailure.notFound);
      await bloc.close();
    });
  });

  test('friends ranking: valid data, ties by completed days then nickname', () async {
    server.addUser('dave', nickname: 'Dave', weekCompleted: 5, weekEligible: 5);
    for (final other in ['bob', 'carol', 'dave']) {
      await alice.sendRequest(server.publicIdOf(other));
      await FakeSocialRepository(server, other).respondToRequest(server.publicIdOf('alice'), accept: true);
    }
    final bloc = FriendsLeaderboardBloc(alice)..add(const FriendsLeaderboardRequested());
    await pumpEventQueue();
    final entries = bloc.state.leaderboard!.entries;
    expect(entries.map((e) => e.displayName), ['Alice_1', 'Dave', null, 'Carol'],
        reason: 'Alice and Dave tie at 100% and 5 days: nickname decides; Bob (no nickname) 20%, Carol 0%');
    expect(entries.first.isMe, isTrue);
    await bloc.close();
  });
}
