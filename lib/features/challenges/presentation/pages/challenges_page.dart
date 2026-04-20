import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/duel_entity.dart';
import '../providers/challenge_template_provider.dart';
import '../providers/duel_provider.dart';
import '../widgets/challenge_template_card.dart';
import '../widgets/duel_card.dart';

class ChallengesPage extends ConsumerWidget {
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duelState = ref.watch(duelNotifierProvider);
    final templateState = ref.watch(challengeTemplateNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';
    final theme = Theme.of(context);

    final visibleDuels = duelState.myDuels
        .where((d) => d.status != DuelStatus.cancelled)
        .where((d) => d.status != DuelStatus.rejected)
        .toList();

    final pendingDuels = visibleDuels
        .where(
          (d) =>
              d.status == DuelStatus.pending || d.status == DuelStatus.accepted,
        )
        .toList();
    final activeDuels = visibleDuels
        .where((d) => d.status == DuelStatus.active)
        .toList();
    final completedSoloDuels = visibleDuels
        .where((d) => d.isSolo && d.status == DuelStatus.completed)
        .toList();
    final completedGroupDuels = visibleDuels
        .where((d) => !d.isSolo && d.status == DuelStatus.completed)
        .toList();

    final pendingCount = duelState.pendingInvites.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(duelNotifierProvider.notifier).loadDuels(),
              ref
                  .read(challengeTemplateNotifierProvider.notifier)
                  .loadTemplates(),
            ]);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'Les défis',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      if (pendingCount > 0) _PendingBadge(count: pendingCount),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Prêt pour les défis ?',
                    style: theme.textTheme.displaySmall,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quêtes collaboratives',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Avance case par case avec tes amis.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: () => context.push(Routes.duels),
                          icon: const Icon(Icons.flag_outlined, size: 18),
                          label: const Text('Ouvrir les quêtes collaboratives'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.textPrimary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (pendingCount > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _PendingInvitesSection(
                      duelState: duelState,
                      currentUserId: currentUserId,
                    ),
                  ),
                ),

              if (visibleDuels.isNotEmpty) ...[
                _SectionHeader(title: 'Mes défis (détails)'),
                SliverList(
                  delegate: SliverChildBuilderDelegate((_, i) {
                    final duel = visibleDuels[i];
                    return DuelCard(duel: duel, currentUserId: currentUserId);
                  }, childCount: visibleDuels.length),
                ),
              ],

              if (pendingDuels.isNotEmpty) ...[
                _SectionHeader(title: 'Défis en attente'),
                SliverToBoxAdapter(
                  child: _HorizontalCardList(
                    children: [
                      ...pendingDuels.map(
                        (d) => _DuelMiniCard(duel: d, statusLabel: 'Attente'),
                      ),
                    ],
                  ),
                ),
              ],

              if (activeDuels.isNotEmpty) ...[
                _SectionHeader(title: 'Défis en cours'),
                SliverToBoxAdapter(
                  child: _HorizontalCardList(
                    children: [
                      ...activeDuels.map(
                        (d) => _DuelMiniCard(duel: d, statusLabel: 'En cours'),
                      ),
                    ],
                  ),
                ),
              ],

              _SectionHeader(title: 'Défi solo'),
              SliverToBoxAdapter(
                child: _HorizontalCardList(
                  children: [
                    ...completedSoloDuels.map(
                      (d) => _DuelMiniCard(duel: d, statusLabel: 'Terminé'),
                    ),
                    ...templateState.soloTemplates.map(
                      (t) => ChallengeTemplateCard(
                        template: t,
                        onTap: () => context.push(Routes.createDuel),
                      ),
                    ),
                    if (completedSoloDuels.isEmpty &&
                        templateState.soloTemplates.isEmpty)
                      const _EmptyCard(label: 'Aucun défi solo'),
                  ],
                ),
              ),

              _SectionHeader(title: 'Défi de groupe'),
              SliverToBoxAdapter(
                child: _HorizontalCardList(
                  children: [
                    ...completedGroupDuels.map(
                      (d) => _DuelMiniCard(duel: d, statusLabel: 'Terminé'),
                    ),
                    ...templateState.groupTemplates.map(
                      (t) => ChallengeTemplateCard(
                        template: t,
                        onTap: () => context.push(Routes.createGroupChallenge),
                      ),
                    ),
                    if (completedGroupDuels.isEmpty &&
                        templateState.groupTemplates.isEmpty)
                      const _EmptyCard(label: 'Aucun défi groupe'),
                  ],
                ),
              ),

              if (templateState.monthlyTemplates.isNotEmpty) ...[
                _SectionHeader(title: 'Défi du mois'),
                SliverToBoxAdapter(
                  child: _HorizontalCardList(
                    children: templateState.monthlyTemplates
                        .map(
                          (t) => ChallengeTemplateCard(
                            template: t,
                            onTap: () =>
                                context.push(Routes.createGroupChallenge),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Créer ton défi', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        'Tu te pense unique ? Vas-y créer ton défi !',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: () => context.push(Routes.createDuel),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.textPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Créer mon défi',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _HorizontalCardList extends StatelessWidget {
  final List<Widget> children;

  const _HorizontalCardList({required this.children});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 182,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

class _DuelMiniCard extends StatelessWidget {
  final DuelEntity duel;
  final String statusLabel;

  const _DuelMiniCard({required this.duel, required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    final desc = duel.description ?? '';
    final name = desc.contains(' • ') ? desc.split(' • ').first : 'Défi';
    final target = duel.targetDistanceMeters;
    final targetLabel = target != null
        ? '${(target / 1000).toStringAsFixed(0)}km'
        : '—';
    final icon = duel.isSolo ? '🏃' : '⚔️';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () =>
            context.push(Routes.duelDetail.replaceFirst(':id', duel.id)),
        child: Container(
          width: 142,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 92,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 34)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _Chip(label: targetLabel, dark: false),
                          const SizedBox(width: 4),
                          _Chip(label: statusLabel, dark: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String label;

  const _EmptyCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 142,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  final int count;

  const _PendingBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count invitation${count > 1 ? 's' : ''}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PendingInvitesSection extends StatelessWidget {
  final DuelState duelState;
  final String currentUserId;

  const _PendingInvitesSection({
    required this.duelState,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...duelState.pendingInvites.map(
          (d) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DuelCard(duel: d, currentUserId: currentUserId),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool dark;

  const _Chip({required this.label, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: dark ? AppColors.textPrimary : AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: dark ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );
  }
}
