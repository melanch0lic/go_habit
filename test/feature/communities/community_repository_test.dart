import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/database/dao/community_dao.dart';
import 'package:go_habit/core/database/drift_database.dart';
import 'package:go_habit/feature/communities/data/community_repository_impl.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';

import 'community_fakes.dart';

void main() {
  late AppDatabase db;
  late FakeCommunityRemote remote;
  late FakeConnect connect;
  late FakeHabitRepository habits;
  late FakeSession session;

  CommunityRepositoryImpl repository() => CommunityRepositoryImpl(
        remote: remote,
        dao: CommunityDao(db),
        appConnect: connect,
        habits: habits,
        session: session,
        synced: const Stream.empty(),
        today: () => today,
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    remote = FakeCommunityRemote();
    connect = FakeConnect();
    habits = FakeHabitRepository();
    session = FakeSession(remote.log, habits: habits, remote: remote);
  });

  tearDown(() async {
    await habits.dispose();
    await db.close();
  });

  Matcher throwsFailure(CommunityFailure failure) =>
      throwsA(isA<CommunityException>().having((e) => e.failure, 'failure', failure));

  group('catalog', () {
    test('loads templates, real counts and memberships', () async {
      remote.otherMembers['reading'] = 2;
      remote.memberships['walking'] = CommunityMembership(templateId: 'walking', joinedOn: today);

      final catalog = await repository().loadCatalog();
      expect(catalog.templates.map((t) => t.id), ['reading', 'walking', 'no-sugar', 'retired']);
      expect(catalog.memberCounts, {'reading': 2, 'walking': 1});
      expect(catalog.memberships.keys, ['walking']);
      expect(catalog.isOffline, isFalse);
    });

    test('offline it shows the cache without participant counts', () async {
      remote.memberships['walking'] = CommunityMembership(templateId: 'walking', joinedOn: today, habitId: 'h1');
      await repository().loadCatalog();

      remote.failure = CommunityFailure.network;
      final catalog = await repository().loadCatalog();
      expect(catalog.isOffline, isTrue);
      expect(catalog.templates, hasLength(4));
      expect(catalog.memberships['walking']!.habitId, 'h1', reason: 'the ranked habit is cached too');
      expect(catalog.memberCounts, isNull, reason: 'no stale numbers');
    });

    test('offline without a cache reports the failure', () async {
      remote.failure = CommunityFailure.network;
      await expectLater(repository().loadCatalog(), throwsFailure(CommunityFailure.network));
    });

    test('an expired session is reported, not hidden behind the cache', () async {
      await repository().loadCatalog();
      remote.failure = CommunityFailure.unauthorized;
      await expectLater(repository().loadCatalog(), throwsFailure(CommunityFailure.unauthorized));
    });
  });

  group('joining without the ranking', () {
    test('needs a connection', () async {
      connect.online = false;
      await expectLater(repository().join('reading'), throwsFailure(CommunityFailure.offline));
      expect(remote.log, isEmpty);
    });

    test('needs no habit and never touches habits', () async {
      final membership = await repository().join('reading');
      expect(membership.isRanked, isFalse);
      expect(habits.log, isEmpty);
    });

    test('joining twice keeps one membership', () async {
      final repo = repository();
      await repo.join('reading');
      await repo.join('reading');
      expect(remote.memberships, hasLength(1));
      expect(await CommunityDao(db).getMemberships(), hasLength(1));
    });
  });

  group('ranked habit', () {
    test('joining with a ranked habit creates exactly one habit from the template, uploads it, then links it',
        () async {
      final membership = await repository().joinWithRankedHabit(reading, title: 'Чтение', description: '30 страниц');

      final habit = habits.habits.single;
      expect(habit.title, 'Чтение');
      expect(habit.description, '30 страниц', reason: "the user's own parameters");
      expect(habit.categoryId, 'education');
      expect(habit.icon, '📚');
      expect(membership.habitId, habit.id);
      expect(remote.log, ['sync', 'join:reading:${habit.id}']);
      expect((await CommunityDao(db).getMemberships()).single.habitId, habit.id);
    });

    test('a member without ranking can add a ranked habit later', () async {
      final repo = repository();
      final joined = await repo.join('reading');
      final ranked = await repo.joinWithRankedHabit(reading, title: 'Чтение', description: 'Читать.');

      expect(ranked.joinedOn, joined.joinedOn, reason: 'still the same membership');
      expect(ranked.habitId, habits.habits.single.id);
      expect(remote.memberships, hasLength(1));
    });

    test('offline nothing is created', () async {
      connect.online = false;
      await expectLater(
        repository().joinWithRankedHabit(reading, title: 'Чтение', description: 'Читать.'),
        throwsFailure(CommunityFailure.offline),
      );
      expect(habits.habits, isEmpty);
    });

    test('if the habit cannot be uploaded, it is removed again and nothing is joined', () async {
      session.syncSucceeds = false;
      await expectLater(
        repository().joinWithRankedHabit(reading, title: 'Чтение', description: 'Читать.'),
        throwsFailure(CommunityFailure.habitNotSynced),
      );
      expect(habits.habits, isEmpty, reason: 'a retry will not leave a duplicate');
      expect(remote.memberships, isEmpty);
      expect(await CommunityDao(db).getMemberships(), isEmpty);
    });
  });

  group('leaving and restoring', () {
    test('leaving removes the membership but keeps the ranked habit', () async {
      final repo = repository();
      await repo.joinWithRankedHabit(reading, title: 'Чтение', description: 'Читать.');
      await repo.leave('reading');

      expect(remote.memberships, isEmpty);
      expect(await CommunityDao(db).getMemberships(), isEmpty);
      expect(habits.habits, hasLength(1));
      expect(habits.log.where((entry) => entry.startsWith('delete')), isEmpty);
    });

    test('memberships survive an app restart', () async {
      await repository().join('reading');
      connect.online = false;
      final restored = await repository().watchMemberships().first;
      expect(restored.keys, ['reading']);
    });
  });

  test('rankings need a connection and come from the server', () async {
    remote.leaderboardRows = [
      const LeaderboardEntry(rank: 1, isMe: true, completedDays: 1, eligibleDays: 1, consistency: 100, rankedCount: 1),
    ];
    final leaderboard = await repository().leaderboard('reading', today: today);
    expect(leaderboard.me!.rank, 1);

    connect.online = false;
    await expectLater(repository().leaderboard('reading', today: today), throwsFailure(CommunityFailure.offline));
  });
}
