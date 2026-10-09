import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/feature/social/data/social_remote_data_source.dart';
import 'package:go_habit/feature/social/domain/models/social.dart';
import 'package:go_habit/feature/social/domain/nickname_rules.dart';
import 'package:go_habit/feature/social/view/social_texts.dart';
import 'package:go_habit/l10n/app_localizations_en.dart';
import 'package:go_habit/l10n/app_localizations_ru.dart';

void main() {
  group('nickname rules (mirror the database check)', () {
    test('accepts letters, digits and underscores starting with a letter', () {
      for (final nickname in ['Bob', 'alice_1', 'A23', 'x' * 20, ' Padded ']) {
        expect(NicknameRules.validate(nickname), isNull, reason: nickname);
      }
    });

    test('rejects everything else with a specific reason', () {
      expect(NicknameRules.validate(''), NicknameError.empty);
      expect(NicknameRules.validate('ab'), NicknameError.tooShort);
      expect(NicknameRules.validate('a' * 21), NicknameError.tooLong);
      expect(NicknameRules.validate('1abc'), NicknameError.mustStartWithLetter);
      expect(NicknameRules.validate('_abc'), NicknameError.mustStartWithLetter);
      expect(NicknameRules.validate('bob smith'), NicknameError.invalidCharacters);
      expect(NicknameRules.validate('бобик'), NicknameError.invalidCharacters);
      expect(NicknameRules.validate('bob.s'), NicknameError.invalidCharacters);
      expect(NicknameRules.validate('Admin'), NicknameError.reserved);
    });

    test('uniqueness ignores case', () {
      expect(NicknameRules.same('Alice_1', 'aLiCe_1 '), isTrue);
      expect(NicknameRules.same('Alice', 'Alice2'), isFalse);
    });

    test('every error has a message in both languages', () {
      for (final l10n in [AppLocalizationsRu(), AppLocalizationsEn()]) {
        for (final error in NicknameError.values) {
          expect(error.message(l10n), isNotEmpty);
        }
      }
    });
  });

  group('models', () {
    test('my profile parses and round-trips through the cache format', () {
      final profile = MyProfile.fromJson(const {
        'public_id': 'p1',
        'nickname': 'Bob',
        'bio': null,
        'avatar': 'fox',
        'stats_visibility': 'everyone',
        'communities_visibility': 'nobody',
      });
      expect(profile.statsVisibility, ProfileVisibility.everyone);
      expect(MyProfile.fromJson(profile.toJson()), profile);
    });

    test('unknown visibility falls back to the private default', () {
      expect(ProfileVisibility.parse('public'), ProfileVisibility.friends);
      expect(Relationship.parse('weird'), Relationship.none);
    });

    test('the graph is split into friends, requests and blocked users', () {
      final now = DateTime.utc(2026, 10, 9);
      SocialConnection connection(String nick, ConnectionKind kind, {bool mine = false, int daysAgo = 0}) =>
          SocialConnection(
            user: PublicUser(publicId: nick, nickname: nick),
            kind: kind,
            since: now.subtract(Duration(days: daysAgo)),
            requestedByMe: mine,
          );
      final graph = SocialGraph(connections: [
        connection('zed', ConnectionKind.friend),
        connection('Amy', ConnectionKind.friend, mine: true, daysAgo: 1),
        connection('Old', ConnectionKind.friend, mine: true, daysAgo: 30),
        connection('In', ConnectionKind.incoming),
        connection('Out', ConnectionKind.outgoing),
        connection('Bad', ConnectionKind.blocked),
      ]);
      expect(graph.friends.map((c) => c.user.nickname), ['Amy', 'Old', 'zed'], reason: 'sorted, case-insensitive');
      expect(graph.incoming, hasLength(1));
      expect(graph.outgoing, hasLength(1));
      expect(graph.blocked, hasLength(1));
      expect(graph.recentlyAccepted(now).map((c) => c.user.nickname), ['Amy'],
          reason: 'only my requests, accepted within a week');
    });

    test('a public profile hides statistics unless visible', () {
      final hidden = PublicProfile.fromJson(const {
        'public_id': 'p1',
        'nickname': 'Bob',
        'relationship': 'none',
        'stats_visible': false,
        'communities_visible': false,
      });
      expect(hidden.weekConsistency, isNull);
      expect(hidden.communities, isNull);

      final visible = PublicProfile.fromJson(const {
        'public_id': 'p1',
        'relationship': 'friends',
        'stats_visible': true,
        'week_completed_days': 5,
        'week_eligible_days': 7,
        'communities_visible': true,
        'communities': ['reading'],
      });
      expect(visible.weekConsistency!.toStringAsFixed(2), '71.43');
      expect(visible.communities, ['reading']);
    });
  });

  test('server errors map to user-facing failures; blocks look like unknown users', () {
    expect(SupabaseSocialDataSource.mapPostgrestFailure('23505'), SocialFailure.nicknameTaken);
    expect(SupabaseSocialDataSource.mapPostgrestFailure('23514'), SocialFailure.nicknameInvalid);
    expect(SupabaseSocialDataSource.mapPostgrestFailure('P0002'), SocialFailure.notFound);
    expect(SupabaseSocialDataSource.mapPostgrestFailure('P0004'), SocialFailure.blockedByMe);
    expect(SupabaseSocialDataSource.mapPostgrestFailure('22023'), SocialFailure.notAllowed);
    expect(SupabaseSocialDataSource.mapPostgrestFailure('42501'), SocialFailure.unauthorized);
    expect(SupabaseSocialDataSource.mapPostgrestFailure('XX000'), SocialFailure.unknown);
    for (final l10n in [AppLocalizationsRu(), AppLocalizationsEn()]) {
      expect(SocialFailure.values.map((f) => f.message(l10n)).toSet(), hasLength(SocialFailure.values.length));
    }
  });
}
