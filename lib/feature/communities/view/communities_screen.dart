import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/core/ui_kit/app_choice_chip.dart';
import 'package:go_habit/feature/communities/bloc/community_catalog_bloc.dart';
import 'package:go_habit/feature/communities/domain/models/habit_template.dart';
import 'package:go_habit/feature/communities/domain/repositories/community_repository.dart';
import 'package:go_habit/feature/communities/view/community_texts.dart';
import 'package:go_habit/feature/communities/view/components/category_style.dart';
import 'package:go_habit/feature/communities/view/components/community_card.dart';
import 'package:go_habit/feature/communities/view/components/week_progress.dart';
import 'package:go_habit/feature/initizialization/scopes/app_scope_container.dart';
import 'package:go_router/go_router.dart';
import 'package:yx_scope_flutter/yx_scope_flutter.dart';

/// Discovery: the habit catalog and the user's communities.
class CommunitiesScreen extends StatelessWidget {
  const CommunitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScopeBuilder<AppScopeContainer>.withPlaceholder(
      builder: (context, scope) => CommunitiesView(repository: scope.communityRepository.get),
    );
  }
}

/// [CommunitiesScreen] with its dependency passed in (used by tests).
class CommunitiesView extends StatelessWidget {
  final CommunityRepository repository;

  const CommunitiesView({required this.repository, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocProvider(
      create: (_) => CommunityCatalogBloc(repository)..add(const CommunityCatalogRequested()),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.communities_title),
            bottom: TabBar(
              tabs: [Tab(text: l10n.communities_tab_catalog), Tab(text: l10n.communities_tab_mine)],
            ),
          ),
          body: const TabBarView(children: [_CatalogTab(), _MyCommunitiesTab()]),
        ),
      ),
    );
  }
}

void _openCommunity(BuildContext context, HabitTemplate template) => context.go(CommunityRoutes.detailOf(template.id));

Future<void> _reload(BuildContext context) {
  final bloc = context.read<CommunityCatalogBloc>()..add(const CommunityCatalogRequested());
  return bloc.stream.firstWhere((state) => state.status != CatalogStatus.loading);
}

class _CatalogTab extends StatelessWidget {
  const _CatalogTab();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<CommunityCatalogBloc, CommunityCatalogState>(
      builder: (context, state) {
        final templates = state.visibleTemplates;
        return RefreshIndicator(
          onRefresh: () => _reload(context),
          child: ListView(
            // The bottom inset includes the floating navigation bar.
            padding: EdgeInsets.only(top: 8, bottom: 16 + MediaQuery.paddingOf(context).bottom),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(l10n.communities_intro, style: context.themeOf.textTheme.bodyMedium),
              ),
              const _SearchField(),
              if (state.categoryIds.isNotEmpty)
                _CategoryFilter(categoryIds: state.categoryIds, selected: state.categoryId),
              if (state.catalog?.isOffline ?? false) _Banner(text: l10n.communities_offline_banner),
              ..._content(context, state, templates),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _content(BuildContext context, CommunityCatalogState state, List<HabitTemplate> templates) {
    final l10n = context.l10n;
    if (state.catalog == null) {
      return switch (state.status) {
        CatalogStatus.failure => [
            _StateMessage(
              text: '${l10n.communities_load_failed} ${state.failure?.message(l10n) ?? ''}',
              actionLabel: l10n.communities_retry,
              onAction: () => context.read<CommunityCatalogBloc>().add(const CommunityCatalogRequested()),
            ),
          ],
        _ => const [Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator.adaptive()))],
      };
    }
    if (templates.isEmpty) return [_StateMessage(text: l10n.communities_empty_search)];
    return [
      for (final template in templates)
        CommunityCard(
          template: template,
          memberCount: state.memberCountOf(template.id),
          isMember: state.membershipOf(template.id) != null,
          onTap: () => _openCommunity(context, template),
        ),
    ];
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final _controller = TextEditingController(text: context.read<CommunityCatalogBloc>().state.query);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    context.read<CommunityCatalogBloc>().add(CommunityCatalogQueryChanged(value));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _controller,
        onChanged: _changed,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l10n.communities_search_hint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    _changed('');
                  },
                ),
          // Fill, border and the focus ring come from the theme.
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        ),
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  final List<String> categoryIds;
  final String? selected;

  const _CategoryFilter({required this.categoryIds, required this.selected});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void select(String? id) => context.read<CommunityCatalogBloc>().add(CommunityCatalogCategorySelected(id));

    Widget chip({required String label, required bool isSelected, required Color color, required VoidCallback onTap}) =>
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: AppChoiceChip(label: label, selected: isSelected, color: color, onSelected: onTap),
        );

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          chip(
            label: l10n.communities_filter_all,
            isSelected: selected == null,
            color: context.themeOf.colorScheme.primary,
            onTap: () => select(null),
          ),
          for (final id in categoryIds)
            Builder(builder: (context) {
              final style = CategoryStyle.of(context, id);
              return chip(label: style.name, isSelected: selected == id, color: style.color, onTap: () => select(id));
            }),
        ],
      ),
    );
  }
}

class _MyCommunitiesTab extends StatelessWidget {
  const _MyCommunitiesTab();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<CommunityCatalogBloc, CommunityCatalogState>(
      builder: (context, state) {
        final joined = state.joinedTemplates;
        final List<Widget> children;
        if (state.catalog == null) {
          children = [
            if (state.status == CatalogStatus.failure)
              _StateMessage(
                text: l10n.communities_load_failed,
                actionLabel: l10n.communities_retry,
                onAction: () => context.read<CommunityCatalogBloc>().add(const CommunityCatalogRequested()),
              )
            else
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator.adaptive())),
          ];
        } else if (joined.isEmpty) {
          children = [
            _StateMessage(
              text: l10n.communities_empty_mine,
              actionLabel: l10n.communities_browse_catalog,
              onAction: () => DefaultTabController.of(context).animateTo(0),
            ),
          ];
        } else {
          children = [
            if (state.catalog!.isOffline) _Banner(text: l10n.communities_offline_banner),
            for (final template in joined)
              CommunityCard(
                template: template,
                memberCount: state.memberCountOf(template.id),
                isMember: true,
                onTap: () => _openCommunity(context, template),
                footer: MembershipProgress(membership: state.membershipOf(template.id)!),
              ),
          ];
        }
        return RefreshIndicator(
          onRefresh: () => _reload(context),
          child: ListView(
            padding: EdgeInsets.only(top: 8, bottom: 16 + MediaQuery.paddingOf(context).bottom),
            children: children,
          ),
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;

  const _Banner({required this.text});

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.theme.warningContainer,
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: context.themeOf.textTheme.bodySmall)),
            ],
          ),
        ),
      );
}

class _StateMessage extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateMessage({required this.text, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          children: [
            Text(text, textAlign: TextAlign.center, style: context.themeOf.textTheme.bodyLarge),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: context.theme.commonColors.green100),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      );
}
