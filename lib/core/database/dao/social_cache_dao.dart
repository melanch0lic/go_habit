import 'package:drift/drift.dart';
import 'package:go_habit/core/database/drift_database.dart';
import 'package:go_habit/core/database/tables/social_cache.dart';

part 'social_cache_dao.g.dart';

@DriftAccessor(tables: [SocialCache])
class SocialCacheDao extends DatabaseAccessor<AppDatabase> with _$SocialCacheDaoMixin {
  SocialCacheDao(super.db);

  Future<String?> read(String key) async =>
      (await (select(socialCache)..where((t) => t.key.equals(key))).getSingleOrNull())?.payload;

  Future<void> write(String key, String payload) => into(socialCache)
      .insertOnConflictUpdate(SocialCacheCompanion.insert(key: key, payload: payload, updatedAt: DateTime.now()));
}
