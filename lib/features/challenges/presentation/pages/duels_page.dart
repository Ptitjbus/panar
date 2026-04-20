import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../shared/widgets/panar_breadcrumb.dart';
import '../../../../shared/widgets/panar_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/group_challenge_provider.dart';
import '../widgets/group_challenge_card.dart';

class DuelsPage extends ConsumerWidget {
  const DuelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupChallengeNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref
              .read(groupChallengeNotifierProvider.notifier)
              .loadChallenges(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PanarBreadcrumb('Quêtes collaboratives'),
                      const SizedBox(height: 12),
                      Text(
                        'À deux on va plus loin !',
                        style: theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Petit pas par petit pas.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              if (state.isLoading &&
                  state.myChallenges.isEmpty &&
                  state.pendingInvites.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (state.pendingInvites.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Text(
                        'Invitations reçues',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((_, i) {
                      final challenge = state.pendingInvites[i];
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
                    }, childCount: state.pendingInvites.length),
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
                if (state.myChallenges.isEmpty)
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
                          challenge: state.myChallenges[i],
                          currentUserId: currentUserId,
                        ),
                      ),
                      childCount: state.myChallenges.length,
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
