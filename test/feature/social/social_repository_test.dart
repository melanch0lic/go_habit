import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/database/dao/social_cache_dao.dart';
import 'package:go_habit/core/database/drift_database.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/social/data/social_remote_data_source.dart';
import 'package:go_habit/feature/social/data/social_repository_impl.dart';
import 'package:go_habit/feature/social/domain/models/social.dart';

import '../communities/community_fakes.dart' show FakeConnect;

class _Remote implements SocialRemoteDataSource {
  final log = <String>[];
  SocialFailure? failure;
  MyProfile profile = const MyProfile(publicId: 'me', nickname: 'Bob');
  List<SocialConnection> graph = [
    SocialConnection(
      user: const PublicUser(publicId: 'p2', nickname: 'Alice'),
      kind: ConnectionKind.friend,
      since: DateTime.utc(2026, 10, 2),
    ),
  ];
  Map<String, Object?>? lastUpdate;

  T _call<T>(String name, T Function() body) {
    log.add(name);
    if (failure case final failure?) throw SocialException(failure);
    return body();
  }

  @override
  Future<MyProfile> fetchMyProfile() async => _call('profile', () => profile);

  @override
  Future<MyProfile> updateMyProfile(Map<String, Object?> fields) async => _call('update', () {
        lastUpdate = fields;
        return profile = MyProfile(publicId: 'me', nickname: fields['nickname'] as String? ?? profile.nickname);
      });

  @override
  Future<NicknameStatus> nicknameStatus(String nickname) async => _call('status', () => NicknameStatus.available);

  @override
  Future<List<UserSearchResult>> search(String nickname) async => _call('search', () => const []);

  @override
  Future<PublicProfile> publicProfile(String publicId, {required CalendarDay today}) async =>
      _call('public', () => PublicProfile(user: PublicUser(publicId: publicId), relationship: Relationship.none));

  @override
  Future<Relationship> relationshipAction(RelationshipAction action, String publicId) async =>
      _call(action.name, () => Relationship.outgoing);

  @override
  Future<List<SocialConnection>> fetchGraph() async => _call('graph', () => graph);

  @override
  Future<List<LeaderboardEntry>> fetchFriendsLeaderboard({required CalendarDay today}) async =>
      _call('leaderboard', () => const []);
}

void main() {
  late AppDatabase db;
  late _Remote remote;
  late FakeConnect connect;
  late SocialRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    remote = _Remote();
    connect = FakeConnect();
    repository = SocialRepositoryImpl(
      remote: remote,
      cache: SocialCacheDao(db),
      appConnect: connect,
      today: () => CalendarDay(2026, 10, 9),
    );
  });

  tearDown(() async {
    await repository.dispose();
    await db.close();
  });

  Matcher throwsFailure(SocialFailure failure) =>
      throwsA(isA<SocialException>().having((e) => e.failure, 'failure', failure));

  test('the own profile and the friends list are available offline from the cache', () async {
    await repository.loadMyProfile();
    await repository.loadGraph();

    remote.failure = SocialFailure.network;
    expect((await repository.loadMyProfile()).nickname, 'Bob');
    final graph = await repository.loadGraph();
    expect(graph.isOffline, isTrue);
    expect(graph.friends.single.user.nickname, 'Alice');
  });

  test('without a cache an offline load reports the failure', () async {
    remote.failure = SocialFailure.network;
    await expectLater(repository.loadMyProfile(), throwsFailure(SocialFailure.network));
    await expectLater(repository.loadGraph(), throwsFailure(SocialFailure.network));
  });

  test('an expired session is reported, not hidden behind the cache', () async {
    await repository.loadGraph();
    remote.failure = SocialFailure.unauthorized;
    await expectLater(repository.loadGraph(), throwsFailure(SocialFailure.unauthorized));
  });

  test('relationship actions need a connection and are never queued', () async {
    connect.online = false;
    final changes = <void>[];
    repository.changes.listen(changes.add);

    await expectLater(repository.sendRequest('p2'), throwsFailure(SocialFailure.offline));
    await pumpEventQueue();
    expect(remote.log, isEmpty, reason: 'nothing was sent');
    expect(changes, isEmpty, reason: 'nothing is reported as delivered');
  });

  test('a confirmed action notifies listeners; a failed one does not', () async {
    final changes = <void>[];
    repository.changes.listen(changes.add);

    expect(await repository.sendRequest('p2'), Relationship.outgoing);
    await pumpEventQueue();
    expect(changes, hasLength(1));

    remote.failure = SocialFailure.notFound;
    await expectLater(repository.respondToRequest('p2', accept: true), throwsFailure(SocialFailure.notFound));
    await pumpEventQueue();
    expect(changes, hasLength(1));
  });

  test('saving trims the nickname and stores an empty bio as none', () async {
    await repository.updateProfile(nickname: '  Bobby ', bio: '   ', avatar: 'fox');
    expect(remote.lastUpdate, {'nickname': 'Bobby', 'bio': null, 'avatar': 'fox'});
  });

  test('invalid nicknames are answered locally without a request', () async {
    connect.online = false;
    expect(await repository.nicknameStatus('1bad'), NicknameStatus.invalid);
    expect(await repository.search('a b'), isEmpty);
    expect(remote.log, isEmpty);
  });
}
