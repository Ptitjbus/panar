import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../shared/widgets/panar_breadcrumb.dart';
import '../../../../shared/widgets/panar_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/duel_provider.dart';
import '../providers/group_challenge_provider.dart';
import '../widgets/duel_card.dart';
import '../widgets/group_challenge_card.dart';

class ChallengesPage extends ConsumerWidget {
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duelState = ref.watch(duelNotifierProvider);
    final groupState = ref.watch(groupChallengeNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';
    final theme = Theme.of(context);
    final isLoading =
        duelState.isLoading &&
        groupState.isLoading &&
        duelState.myDuels.isEmpty &&
        duelState.pendingInvites.isEmpty &&
        groupState.myChallenges.isEmpty &&
        groupState.pendingInvites.isEmpty;

    final pendingCount =
        duelState.pendingInvites.length + groupState.pendingInvites.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(duelNotifierProvider.notifier).loadDuels(),
              ref
                  .read(groupChallengeNotifierProvider.notifier)
                  .loadChallenges(),
            ]);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PanarBreadcrumb('Défis & Quêtes'),
                      const SizedBox(height: 12),
                      Text(
                        'Prêt pour les défis ?',
                        style: theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Défis one-shot et quêtes collaboratives.",
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              if (isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (pendingCount > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: _PendingBanner(count: pendingCount),
                    ),
                  ),

                if (duelState.pendingInvites.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(
                        'Invitations défis one-shot',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                        child: DuelCard(
                          duel: duelState.pendingInvites[i],
                          currentUserId: currentUserId,
                        ),
                      ),
                      childCount: duelState.pendingInvites.length,
                    ),
                  ),
                ],

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Text(
                      'Mes défis one-shot',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                if (duelState.myDuels.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(
                        'Aucun défi one-shot pour le moment.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                        child: DuelCard(
                          duel: duelState.myDuels[i],
                          currentUserId: currentUserId,
                        ),
                      ),
                      childCount: duelState.myDuels.length,
                    ),
                  ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: PanarButton(
                      label: 'Créer un défi one-shot',
                      onPressed: () => context.push(Routes.createDuel),
                    ),
                  ),
                ),

                if (groupState.pendingInvites.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(
                        'Invitations quêtes collaboratives',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((_, i) {
                      final challenge = groupState.pendingInvites[i];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                        child: GroupChallengeCard(
                          challenge: challenge,
                          currentUserId: currentUserId,
                          onRespond: (accept) => ref
                              .read(groupChallengeNotifierProvider.notifier)
                              .respondToChallenge(challenge.id, accept: accept),
                        ),
                      );
                    }, childCount: groupState.pendingInvites.length),
                  ),
                ],

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Text(
                      'Mes quêtes collaboratives',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                if (groupState.myChallenges.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(
                        'Aucune quête collaborative pour le moment.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                        child: GroupChallengeCard(
                          challenge: groupState.myChallenges[i],
                          currentUserId: currentUserId,
                        ),
                      ),
                      childCount: groupState.myChallenges.length,
                    ),
                  ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    child: PanarButton(
                      label: 'Créer une quête collaborative',
                      onPressed: () =>
                          context.push(Routes.createGroupChallenge),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  final int count;
  const _PendingBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.mark_email_unread_outlined,
            color: AppColors.textPrimary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            '$count invitation${count > 1 ? 's' : ''} en attente',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
