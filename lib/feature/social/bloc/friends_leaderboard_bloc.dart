import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/social/domain/models/social.dart';
import 'package:go_habit/feature/social/domain/repositories/social_repository.dart';

final class FriendsLeaderboardRequested {
  const FriendsLeaderboardRequested();
}

enum LeaderboardLoad { loading, ready, failure }

@immutable
final class FriendsLeaderboardState {
  final LeaderboardLoad status;

  /// The last loaded ranking; kept while reloading.
  final CommunityLeaderboard? leaderboard;
  final SocialFailure? failure;

  const FriendsLeaderboardState({this.status = LeaderboardLoad.loading, this.leaderboard, this.failure});
}

/// This week's ranking of the user and their friends, computed by the server.
class FriendsLeaderboardBloc extends Bloc<FriendsLeaderboardRequested, FriendsLeaderboardState> {
  final SocialRepository _repository;

  FriendsLeaderboardBloc(this._repository) : super(const FriendsLeaderboardState()) {
    on<FriendsLeaderboardRequested>((event, emit) async {
      emit(FriendsLeaderboardState(leaderboard: state.leaderboard));
      try {
        emit(FriendsLeaderboardState(
          status: LeaderboardLoad.ready,
          leaderboard: await _repository.friendsLeaderboard(),
        ));
      } on SocialException catch (e) {
        emit(FriendsLeaderboardState(
            status: LeaderboardLoad.failure, leaderboard: state.leaderboard, failure: e.failure));
      }
    }, transformer: restartable());
  }
}
