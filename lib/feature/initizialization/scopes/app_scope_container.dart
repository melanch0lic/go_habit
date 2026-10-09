import 'package:dio/dio.dart';
import 'package:go_habit/core/app_connect/src/app_connect.dart';
import 'package:go_habit/core/database/dao/habit_category_dao.dart';
import 'package:go_habit/core/database/dao/habit_completion_dao.dart';
import 'package:go_habit/core/database/dao/habits_dao.dart';
import 'package:go_habit/core/database/drift_database.dart';
import 'package:go_habit/core/router/app_router.dart';
import 'package:go_habit/core/sync/supabase_sync_remote_api.dart';
import 'package:go_habit/core/sync/sync_service.dart';
import 'package:go_habit/feature/auth/data/repositories/authentication_repository_impl.dart';
import 'package:go_habit/feature/auth/domain/repositories/i_authentication_repository.dart';
import 'package:go_habit/feature/categories/data/data_sources/local/local_habit_category_datasource.dart';
import 'package:go_habit/feature/categories/data/data_sources/remote/remote_habit_category_datasource.dart';
import 'package:go_habit/feature/categories/data/repositories/habit_category_repository_implementation.dart';
import 'package:go_habit/feature/categories/domain/repositories/habit_category_repository.dart';
import 'package:go_habit/feature/habit_stats/data/data_sources/local/local_habit_stats_datasource.dart';
import 'package:go_habit/feature/habit_stats/data/repositories/habit_stats_repository_implementation.dart';
import 'package:go_habit/feature/habit_stats/domain/repositories/habit_stats_repository.dart';
import 'package:go_habit/feature/habits/data/data_sources/local/local_habit_data_source.dart';
import 'package:go_habit/feature/habits/data/repositories/habit_repository_implementation.dart';
import 'package:go_habit/feature/habits/domain/repositories/habit_repository.dart';
import 'package:go_habit/feature/home/data/repositories/quote_repository_implementation.dart';
import 'package:go_habit/feature/home/domain/repositories/quote_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yx_scope/yx_scope.dart';

class AppScopeContainer extends ScopeContainer {
  @override
  List<Set<AsyncDep<Object?>>> get initializeQueue => [
        {syncService},
      ];

  late final appConnect = dep<IAppConnect>(() => const AppConnect());
  late final appDatabase = dep<AppDatabase>(AppDatabase.new);
  late final dio = dep<Dio>(Dio.new);
  late final supabaseClient = dep<SupabaseClient>(() => Supabase.instance.client);

  late final syncService = rawAsyncDep<SyncService>(
    () {
      final auth = supabaseClient.get.auth;
      return SyncService(
        database: appDatabase.get,
        remoteApi: SupabaseSyncRemoteApi(supabaseClient.get),
        appConnect: appConnect.get,
        userIdChanges: auth.onAuthStateChange.map((state) => state.session?.user.id),
        currentUserId: () => auth.currentUser?.id,
      );
    },
    init: (service) async => service.start(),
    dispose: (service) => service.dispose(),
  );

  late final localHabitDataSource = dep<LocalHabitDataSource>(
    () => DriftHabitDataSource(HabitsDao(appDatabase.get)),
  );

  late final localHabitCategoryDataSource = dep<LocalHabitCategoryDatasource>(
    () => DriftHabitCategoryDataSource(HabitCategoryDao(appDatabase.get)),
  );

  late final remoteHabitCategoryDataSource =
      dep<RemoteHabitCategoryDatasource>(() => SupabaseHabitCategoryDataSource(supabaseClient.get));

  late final localHabitStatsDataSource = dep<LocalHabitStatsDataSource>(
    () => LocalStatsDataSourceImpl(HabitCompletionDao(appDatabase.get)),
  );

  late final habitStatsRepository = dep<HabitStatsRepository>(
    () => HabitStatsRepositoryImplementation(localHabitStatsDataSource.get, syncService.get),
  );

  late final quoteRepository = dep<QuoteRepository>(() => QuoteRepositoryImplementation(dio.get));

  late final authRepositoryDep = dep<IAuthenticationRepository>(() => AuthenticationRepositoryImpl(supabaseClient.get));

  late final habitRepositoryDep = dep<HabitRepository>(
    () => HabitsRepositoryImplementation(localHabitDataSource.get, syncService.get),
  );

  late final habitCategoriesRepositoryDep = dep<HabitCategoryRepository>(() => HabitCategoryRepositoryImplementation(
      localHabitCategoryDataSource.get, remoteHabitCategoryDataSource.get, appConnect.get));

  late final routerConfig = dep(() {
    final auth = supabaseClient.get.auth;
    return AppRouter(
      isSignedIn: () => auth.currentSession != null,
      authChanges: auth.onAuthStateChange,
    ).routerConfig;
  });
}

class AppScopeHolder extends ScopeHolder<AppScopeContainer> {
  @override
  AppScopeContainer createContainer() {
    return AppScopeContainer();
  }
}
