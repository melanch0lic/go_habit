part of 'community_catalog_bloc.dart';

enum CatalogStatus { initial, loading, ready, failure }

@immutable
final class CommunityCatalogState {
  final CatalogStatus status;

  /// The last loaded catalog; kept while reloading or after a failed reload.
  final CommunityCatalog? catalog;
  final CommunityFailure? failure;
  final String query;
  final String? categoryId;

  const CommunityCatalogState({
    this.status = CatalogStatus.initial,
    this.catalog,
    this.failure,
    this.query = '',
    this.categoryId,
  });

  /// Joinable templates matching the search and the category filter.
  List<HabitTemplate> get visibleTemplates {
    final query = this.query.trim().toLowerCase();
    return [
      for (final template in catalog?.templates ?? const <HabitTemplate>[])
        if (template.isActive && (categoryId == null || template.categoryId == categoryId) && template.matches(query))
          template,
    ];
  }

  /// Communities the user belongs to, including retired ones.
  List<HabitTemplate> get joinedTemplates {
    final memberships = catalog?.memberships ?? const {};
    return [
      for (final template in catalog?.templates ?? const <HabitTemplate>[])
        if (memberships.containsKey(template.id)) template,
    ];
  }

  /// Categories that have at least one joinable template, in catalog order.
  List<String> get categoryIds => {
        for (final template in catalog?.templates ?? const <HabitTemplate>[])
          if (template.isActive) template.categoryId,
      }.toList();

  CommunityMembership? membershipOf(String templateId) => catalog?.memberships[templateId];

  /// A real participant count, or null when unknown (offline).
  int? memberCountOf(String templateId) {
    final counts = catalog?.memberCounts;
    return counts == null ? null : counts[templateId] ?? 0;
  }

  CommunityCatalogState copyWith({
    CatalogStatus? status,
    CommunityCatalog? catalog,
    CommunityFailure? Function()? failure,
    String? query,
    String? Function()? categoryId,
  }) =>
      CommunityCatalogState(
        status: status ?? this.status,
        catalog: catalog ?? this.catalog,
        failure: failure != null ? failure() : this.failure,
        query: query ?? this.query,
        categoryId: categoryId != null ? categoryId() : this.categoryId,
      );
}
