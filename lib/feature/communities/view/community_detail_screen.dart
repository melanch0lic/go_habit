import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/core/ui_kit/app_haptics.dart';
import 'package:go_habit/core/ui_kit/pressable_scale.dart';
import 'package:go_habit/feature/communities/bloc/community_detail_bloc.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/communities/domain/models/habit_template.dart';
import 'package:go_habit/feature/communities/domain/repositories/community_repository.dart';
import 'package:go_habit/feature/communities/view/community_texts.dart';
import 'package:go_habit/feature/communities/view/components/category_style.dart';
import 'package:go_habit/feature/communities/view/components/leaderboard_section.dart';
import 'package:go_habit/feature/communities/view/components/ranked_habit_sheet.dart';
import 'package:go_habit/feature/communities/view/components/week_progress.dart';
import 'package:go_habit/feature/habits/bloc/habits_bloc.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/view/habit_texts.dart';
import 'package:go_habit/feature/initizialization/scopes/app_scope_container.dart';
import 'package:yx_scope_flutter/yx_scope_flutter.dart';

/// A community: what it is about, the user's membership and ranked habit, and the
/// weekly ranking.
class CommunityDetailScreen extends StatelessWidget {
  final String templateId;

  const CommunityDetailScreen({required this.templateId, super.key});

  @override
  Widget build(BuildContext context) {
    return ScopeBuilder<AppScopeContainer>.withPlaceholder(
      builder: (context, scope) =>
          CommunityDetailView(templateId: templateId, repository: scope.communityRepository.get),
    );
  }
}

/// [CommunityDetailScreen] with its dependency passed in (used by tests).
class CommunityDetailView extends StatelessWidget {
  final String templateId;
  final CommunityRepository repository;

  const CommunityDetailView({required this.templateId, required this.repository, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CommunityDetailBloc(repository, templateId: templateId)..add(const CommunityDetailStarted()),
      child: const _DetailBody(),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody();

  void _onNotice(BuildContext context, CommunityDetailState state) {
    final notice = state.notice;
    if (notice == null) return;
    final l10n = context.l10n;
    final text = switch (notice.outcome) {
      CommunityOutcome.joined => l10n.community_joined,
      CommunityOutcome.joinedRanked => l10n.community_joined_ranked,
      CommunityOutcome.rankedHabitCreated => l10n.community_ranked_habit_created,
      CommunityOutcome.left => l10n.community_left,
      CommunityOutcome.failed => (notice.failure ?? CommunityFailure.unknown).message(l10n),
    };
    if (notice.outcome != CommunityOutcome.failed) AppHaptics.success();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<CommunityDetailBloc, CommunityDetailState>(
      listenWhen: (previous, current) => current.notice != null,
      listener: _onNotice,
      builder: (context, state) {
        final template = state.template;
        return Scaffold(
          appBar: AppBar(title: Text(template?.titleFor(languageCodeOf(context)) ?? l10n.communities_title)),
          body: switch (template) {
            null when state.templateStatus == LoadStatus.failure => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (state.templateFailure ?? CommunityFailure.unknown).message(l10n),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => context.read<CommunityDetailBloc>().add(const CommunityDetailStarted()),
                        child: Text(l10n.communities_retry),
                      ),
                    ],
                  ),
                ),
              ),
            null => const Center(child: CircularProgressIndicator.adaptive()),
            final template => RefreshIndicator(
                onRefresh: () {
                  final bloc = context.read<CommunityDetailBloc>()..add(const CommunityLeaderboardRefreshed());
                  return bloc.stream.firstWhere((s) => s.leaderboardStatus != LoadStatus.loading);
                },
                child: ListView(
                  // The bottom inset includes the floating navigation bar.
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    _Header(template: template, memberCount: state.memberCount),
                    const SizedBox(height: 12),
                    _Membership(state: state, template: template),
                    const SizedBox(height: 12),
                    const _Rules(),
                    const SizedBox(height: 20),
                    LeaderboardSection(
                      state: state,
                      onRetry: () => context.read<CommunityDetailBloc>().add(const CommunityLeaderboardRefreshed()),
                    ),
                  ],
                ),
              ),
          },
        );
      },
    );
  }
}

/// Dark card in the style of the habit cards.
class _DarkCard extends StatelessWidget {
  final Widget child;

  const _DarkCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration:
            BoxDecoration(color: context.theme.featureSurface, borderRadius: BorderRadius.circular(AppRadius.card)),
        child: DefaultTextStyle.merge(style: TextStyle(color: context.theme.onFeatureSurface), child: child),
      );
}

class _Header extends StatelessWidget {
  final HabitTemplate template;
  final int? memberCount;

  const _Header({required this.template, required this.memberCount});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = languageCodeOf(context);
    final target = template.targetText(l10n);
    final memberCount = this.memberCount;

    return _DarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EmojiBadge(template.icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        template.titleFor(language),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 6),
                    CategoryPill(categoryId: template.categoryId),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(template.descriptionFor(language), style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 12),
          if (target != null) _InfoLine(icon: Icons.flag_outlined, text: l10n.community_recommended_target(target)),
          _InfoLine(
            icon: Icons.event_repeat,
            text: l10n.community_recommended_schedule(l10n.scheduleSummary(template.recommendedSchedule)),
          ),
          if (memberCount != null)
            _InfoLine(
              icon: Icons.groups_outlined,
              text: memberCount > 0 ? l10n.communities_members(memberCount) : l10n.communities_no_members_yet,
            ),
          if (!template.isActive) _InfoLine(icon: Icons.lock_outline, text: l10n.community_retired),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.theme.onFeatureSurfaceMuted),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
          ],
        ),
      );
}

class _Membership extends StatelessWidget {
  final CommunityDetailState state;
  final HabitTemplate template;

  const _Membership({required this.state, required this.template});

  /// Joining: a ranked habit or no ranking. Later: a ranked habit only.
  Future<void> _openSheet(BuildContext context) async {
    final bloc = context.read<CommunityDetailBloc>();
    final choice = await RankedHabitSheet.show(
      context,
      template: template,
      habits: context.read<HabitsBloc>().state.habits,
      joining: !state.isMember,
    );
    switch (choice) {
      case CreateRankedHabit(:final title, :final description, :final schedule):
        bloc.add(RankedHabitRequested(title: title, description: description, schedule: schedule));
      case JoinWithoutRanking():
        bloc.add(const CommunityJoinRequested());
      case null:
        break;
    }
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final bloc = context.read<CommunityDetailBloc>();
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.themeOf.cardColor,
        title: Text(l10n.community_leave_title),
        content: Text(l10n.community_leave_message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.themeOf.colorScheme.error),
            child: Text(l10n.community_leave_confirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) bloc.add(const CommunityLeaveRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final membership = state.membership;
    final busy = state.isBusy;

    if (membership == null) {
      if (!template.isActive) return const SizedBox.shrink();
      return PressableScale(
        enabled: !busy,
        child: ElevatedButton(
          onPressed: busy ? null : () => _openSheet(context),
          child: busy
              // The busy button is disabled, so the spinner uses the brand color on its muted fill.
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.community_join),
        ),
      );
    }

    final habits = context.select<HabitsBloc, List<Habit>>((bloc) => bloc.state.habits);
    // Without a usable ranked habit the member can create one at any time.
    final canCreateRanked = template.isActive && membership.rankedHabitStatus(habits) != RankedHabitStatus.available;

    return _DarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: context.theme.commonColors.green100),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.community_member_since(membership.joinedOn.toDateTime()),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (busy) const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 12),
          MembershipProgress(membership: membership),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (canCreateRanked)
                TextButton.icon(
                  onPressed: busy ? null : () => _openSheet(context),
                  style: TextButton.styleFrom(foregroundColor: context.theme.commonColors.green100),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.community_create_ranked_habit),
                ),
              TextButton.icon(
                onPressed: busy ? null : () => _confirmLeave(context),
                // On the dark feature surface in both themes: the dark theme's error color.
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFF28B82)),
                icon: const Icon(Icons.logout),
                label: Text(l10n.community_leave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Rules extends StatelessWidget {
  const _Rules();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Theme(
        // No divider lines around the expanded tile.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.community_rules_title, style: const TextStyle(fontWeight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [Text(l10n.community_rules_body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4))],
        ),
      ),
    );
  }
}
