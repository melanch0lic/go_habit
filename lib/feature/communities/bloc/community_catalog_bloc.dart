import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/communities/domain/models/habit_template.dart';
import 'package:go_habit/feature/communities/domain/repositories/community_repository.dart';

part 'community_catalog_event.dart';
part 'community_catalog_state.dart';

/// The catalog with search and category filter, and the user's communities.
class CommunityCatalogBloc extends Bloc<CommunityCatalogEvent, CommunityCatalogState> {
  final CommunityRepository _repository;
  StreamSubscription<Map<String, CommunityMembership>>? _memberships;

  CommunityCatalogBloc(this._repository) : super(const CommunityCatalogState()) {
    // A newer load replaces one in flight (e.g. pull-to-refresh after a retry).
    on<CommunityCatalogRequested>(_onRequested, transformer: restartable());
    on<CommunityCatalogQueryChanged>((event, emit) => emit(state.copyWith(query: event.query)));
    on<CommunityCatalogCategorySelected>(
      (event, emit) => emit(state.copyWith(categoryId: () => event.categoryId)),
    );
    on<_MembershipsChanged>((event, emit) {
      final catalog = state.catalog;
      if (catalog != null) emit(state.copyWith(catalog: catalog.copyWith(memberships: event.memberships)));
    });

    // Joining or leaving on the detail screen updates the cache, and so this list.
    _memberships = _repository.watchMemberships().listen((memberships) => add(_MembershipsChanged(memberships)));
  }

  Future<void> _onRequested(CommunityCatalogRequested event, Emitter<CommunityCatalogState> emit) async {
    emit(state.copyWith(status: CatalogStatus.loading));
    try {
      final catalog = await _repository.loadCatalog();
      emit(state.copyWith(status: CatalogStatus.ready, catalog: catalog, failure: () => null));
    } on CommunityException catch (e) {
      emit(state.copyWith(status: CatalogStatus.failure, failure: () => e.failure));
    } on Object {
      emit(state.copyWith(status: CatalogStatus.failure, failure: () => CommunityFailure.unknown));
    }
  }

  @override
  Future<void> close() {
    _memberships?.cancel();
    return super.close();
  }
}
