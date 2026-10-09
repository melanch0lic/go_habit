import 'package:drift/drift.dart';
import 'package:go_habit/core/database/drift_database.dart';
import 'package:go_habit/core/database/tables/community_cache.dart';

part 'community_dao.g.dart';

@DriftAccessor(tables: [HabitTemplates, CommunityMemberships])
class CommunityDao extends DatabaseAccessor<AppDatabase> with _$CommunityDaoMixin {
  CommunityDao(super.db);

  Future<List<HabitTemplateEntry>> getTemplates() =>
      (select(habitTemplates)..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).get();

  Future<void> replaceTemplates(List<HabitTemplatesCompanion> templates) => transaction(() async {
        await delete(habitTemplates).go();
        await batch((batch) => batch.insertAll(habitTemplates, templates));
      });

  Future<List<CommunityMembershipEntry>> getMemberships() => select(communityMemberships).get();

  Stream<List<CommunityMembershipEntry>> watchMemberships() => select(communityMemberships).watch();

  Future<void> replaceMemberships(List<CommunityMembershipsCompanion> memberships) => transaction(() async {
        await delete(communityMemberships).go();
        await batch((batch) => batch.insertAll(communityMemberships, memberships));
      });

  Future<void> saveMembership(CommunityMembershipsCompanion membership) =>
      into(communityMemberships).insertOnConflictUpdate(membership);

  Future<void> deleteMembership(String templateId) =>
      (delete(communityMemberships)..where((t) => t.templateId.equals(templateId))).go();
}
