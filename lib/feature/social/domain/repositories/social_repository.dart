import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/social/domain/models/social.dart';

/// Profiles, friends and blocking. Failures are thrown as [SocialException].
///
/// The server is the source of truth for every relationship: actions need a
/// connection and are never reported as done before the server confirmed them. The
/// own profile and the friends list are cached for offline viewing.
abstract interface class SocialRepository {
  /// The signed-in user's profile; the cached copy when offline.
  Future<MyProfile> loadMyProfile();

  /// Saves the public profile fields. A nickname taken meanwhile by someone else
  /// fails with [SocialFailure.nicknameTaken].
  Future<MyProfile> updateProfile({required String nickname, String? bio, String? avatar});

  Future<MyProfile> updatePrivacy({
    required ProfileVisibility stats,
    required ProfileVisibility communities,
  });

  /// Availability feedback while typing; the database decides on save.
  Future<NicknameStatus> nicknameStatus(String nickname);

  /// Exact, case-insensitive nickname search.
  Future<List<UserSearchResult>> search(String nickname);

  Future<PublicProfile> publicProfile(String publicId);

  Future<Relationship> sendRequest(String publicId);
  Future<Relationship> respondToRequest(String publicId, {required bool accept});
  Future<Relationship> cancelRequest(String publicId);
  Future<Relationship> removeFriend(String publicId);
  Future<Relationship> block(String publicId);
  Future<Relationship> unblock(String publicId);

  /// Friends, requests and blocked users; the cached copy when offline.
  Future<SocialGraph> loadGraph();

  /// The user and their friends ranked by this week's consistency.
  Future<CommunityLeaderboard> friendsLeaderboard();

  /// Emits after a relationship changed on the server, so lists can reload.
  Stream<void> get changes;
}
