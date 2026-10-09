part of 'community_catalog_bloc.dart';

sealed class CommunityCatalogEvent {
  const CommunityCatalogEvent();
}

/// Loads (or reloads) the catalog.
final class CommunityCatalogRequested extends CommunityCatalogEvent {
  const CommunityCatalogRequested();
}

final class CommunityCatalogQueryChanged extends CommunityCatalogEvent {
  final String query;

  const CommunityCatalogQueryChanged(this.query);
}

/// Null shows every category.
final class CommunityCatalogCategorySelected extends CommunityCatalogEvent {
  final String? categoryId;

  const CommunityCatalogCategorySelected(this.categoryId);
}

final class _MembershipsChanged extends CommunityCatalogEvent {
  final Map<String, CommunityMembership> memberships;

  const _MembershipsChanged(this.memberships);
}
