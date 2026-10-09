import 'package:drift/drift.dart';

/// Offline copies of server-confirmed social data (the user's own profile, friends and
/// requests) as JSON. Never edited locally: social actions need a connection.
@DataClassName('SocialCacheEntry')
class SocialCache extends Table {
  TextColumn get key => text()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}
