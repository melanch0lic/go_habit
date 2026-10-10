import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/feature/communities/bloc/community_catalog_bloc.dart';
import 'package:go_habit/feature/communities/bloc/community_detail_bloc.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';

import 'community_fakes.dart';

void main() {
  late FakeCommunityRepository repository;

  setUp(() => repository = FakeCommunityRepository());
  tearDown(() => repository.dispose());

  group('catalog', () {
    late CommunityCatalogBloc bloc;

    setUp(() => bloc = CommunityCatalogBloc(repository));
    tearDown(() => bloc.close());

    Future<void> load() async {
      bloc.add(const CommunityCatalogRequested());
      await pumpEventQueue();
    }

    test('loads the catalog; retired templates are not offered', () async {
      await load();
      expect(bloc.state.status, CatalogStatus.ready);
      expect(bloc.state.visibleTemplates.map((t) => t.id), ['reading', 'walking', 'strength-training', 'no-sugar']);
      expect(bloc.state.memberCountOf('reading'), 3);
      expect(bloc.state.memberCountOf('walking'), 0, reason: 'a loaded count of zero is real');
    });

    test('search and category filter combine', () async {
      await load();
      bloc.add(const CommunityCatalogCategorySelected('health'));
      await pumpEventQueue();
      expect(bloc.state.visibleTemplates.map((t) => t.id), ['walking', 'strength-training', 'no-sugar']);

      bloc.add(const CommunityCatalogQueryChanged('  SWEETS '));
      await pumpEventQueue();
      expect(bloc.state.visibleTemplates.map((t) => t.id), ['no-sugar']);

      bloc
        ..add(const CommunityCatalogCategorySelected(null))
        ..add(const CommunityCatalogQueryChanged('xyz'));
      await pumpEventQueue();
      expect(bloc.state.visibleTemplates, isEmpty);
    });

    test('a failure can be retried', () async {
      repository.failures['catalog'] = CommunityFailure.network;
      await load();
      expect(bloc.state.status, CatalogStatus.failure);

      repository.failures.clear();
      await load();
      expect(bloc.state.status, CatalogStatus.ready);
      expect(bloc.state.failure, isNull);
    });

    test('joining elsewhere shows up in "My communities", including retired ones', () async {
      await load();
      await repository.join('walking');
      await repository.join('retired');
      await pumpEventQueue();
      expect(bloc.state.joinedTemplates.map((t) => t.id), ['walking', 'retired']);
    });

    test('offline counts are unknown, not zero', () async {
      repository.catalog = const CommunityCatalog(templates: [reading], memberships: {}, isOffline: true);
      await load();
      expect(bloc.state.memberCountOf('reading'), isNull);
    });
  });

  group('detail', () {
    late CommunityDetailBloc bloc;
    late List<CommunityDetailState> states;

    Future<void> start() async {
      bloc = CommunityDetailBloc(repository, templateId: 'reading', today: () => today);
      states = [];
      bloc.stream.listen(states.add);
      bloc.add(const CommunityDetailStarted());
      await pumpEventQueue();
    }

    tearDown(() => bloc.close());

    List<CommunityOutcome> outcomes() => [
          for (final state in states)
            if (state.notice case final notice?) notice.outcome,
        ];

    int leaderboardLoads() => repository.log.where((e) => e.startsWith('leaderboard')).length;

    test('loads the template, the ranking and the real member count', () async {
      await start();
      expect(bloc.state.template, reading);
      expect(bloc.state.leaderboardStatus, LoadStatus.ready);
      expect(bloc.state.memberCount, 3);
      expect(bloc.state.isMember, isFalse);
    });

    test('joining with a ranked habit', () async {
      await start();
      bloc.add(const RankedHabitRequested(title: 'Чтение', description: '30 страниц'));
      await pumpEventQueue();

      expect(bloc.state.membership!.habitId, 'ranked-habit');
      expect(outcomes(), [CommunityOutcome.joinedRanked]);
      expect(leaderboardLoads(), 2, reason: 'reloaded after joining');
    });

    test('joining without the ranking, then adding a ranked habit later', () async {
      await start();
      bloc.add(const CommunityJoinRequested());
      await pumpEventQueue();
      expect(bloc.state.isMember, isTrue);
      expect(bloc.state.membership!.isRanked, isFalse);

      bloc.add(const RankedHabitRequested(title: 'Чтение', description: 'Читать.'));
      await pumpEventQueue();
      expect(bloc.state.membership!.isRanked, isTrue);
      expect(outcomes(), [CommunityOutcome.joined, CommunityOutcome.rankedHabitCreated]);
    });

    test('repeated taps while joining send one request', () async {
      await start();
      repository.gate = Completer<void>();
      for (var i = 0; i < 3; i++) {
        bloc.add(const CommunityJoinRequested());
      }
      await pumpEventQueue();
      expect(bloc.state.isBusy, isTrue);

      repository.gate!.complete();
      await pumpEventQueue();
      expect(repository.log.where((e) => e.startsWith('join')), hasLength(1));
      expect(bloc.state.isBusy, isFalse);
    });

    test('leaving', () async {
      await repository.join('reading');
      await start();
      bloc.add(const CommunityLeaveRequested());
      await pumpEventQueue();
      expect(bloc.state.isMember, isFalse);
      expect(outcomes(), [CommunityOutcome.left]);
    });

    test('a failed ranked habit explains why and changes nothing', () async {
      await start();
      repository.failures['ranked'] = CommunityFailure.habitNotSynced;
      bloc.add(const RankedHabitRequested(title: 'Чтение', description: 'Читать.'));
      await pumpEventQueue();

      final notice = states.lastWhere((s) => s.notice != null).notice!;
      expect(notice.outcome, CommunityOutcome.failed);
      expect(notice.failure, CommunityFailure.habitNotSynced);
      expect(bloc.state.isMember, isFalse);
      expect(bloc.state.isBusy, isFalse);
    });

    test('an offline ranking is reported; unsynced marks are flagged', () async {
      repository
        ..failures['leaderboard'] = CommunityFailure.offline
        ..unsynced = true;
      await start();
      expect(bloc.state.leaderboardStatus, LoadStatus.failure);
      expect(bloc.state.leaderboardFailure, CommunityFailure.offline);
      expect(bloc.state.hasUnsyncedChanges, isTrue);
    });

    test('a completed synchronization reloads the ranking', () async {
      await start();
      final before = leaderboardLoads();
      repository.synced.add(null);
      await pumpEventQueue();
      expect(leaderboardLoads(), before + 1);
    });

    test('an unknown community is reported', () async {
      bloc = CommunityDetailBloc(repository, templateId: 'missing')..add(const CommunityDetailStarted());
      await pumpEventQueue();
      expect(bloc.state.templateStatus, LoadStatus.failure);
    });
  });
}
