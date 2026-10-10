import 'package:drift/drift.dart';

/// Offline copy of the habit catalog (`public.habit_template`). The server is the
/// source of truth; the cache is replaced on every successful refresh.
@DataClassName('HabitTemplateEntry')
class HabitTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text()();

  /// Localized texts as JSON: `{"ru": "...", "en": "..."}`.
  TextColumn get title => text()();
  TextColumn get description => text()();
  TextColumn get icon => text()();
  IntColumn get targetValue => integer().nullable()();
  TextColumn get targetUnit => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Recommended schedule, as on `public.habit_template` (see `HabitSchedule`).
  TextColumn get scheduleType => text().withDefault(const Constant('daily'))();
  IntColumn get weeklyTarget => integer().nullable()();
  IntColumn get scheduleDays => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Offline copy of the signed-in user's community memberships. Joining and leaving
/// require a connection; this table only mirrors the server's answer.
@DataClassName('CommunityMembershipEntry')
class CommunityMemberships extends Table {
  TextColumn get templateId => text()();

  /// The ranked habit (created from the template); null when not ranked.
  TextColumn get habitId => text().nullable()();

  /// Local calendar day, `YYYY-MM-DD`.
  TextColumn get joinedOn => text()();

  @override
  Set<Column> get primaryKey => {templateId};
}
