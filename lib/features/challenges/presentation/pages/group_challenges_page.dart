import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/group_challenge_provider.dart';
import '../widgets/group_challenge_card.dart';

class GroupChallengesPage extends ConsumerWidget {
  const GroupChallengesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupChallengeNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Défis groupe 🏆'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push(Routes.createGroupChallenge),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(groupChallengeNotifierProvider.notifier).loadChallenges(),
        child: state.isLoading &&
                state.myChallenges.isEmpty &&
                state.pendingInvites.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  if (state.pendingInvites.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Invitations reçues',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final c = state.pendingInvites[i];
                          return GroupChallengeCard(
                            challenge: c,
                            currentUserId: currentUserId,
                            onRespond: (accept) => ref
                                .read(groupChallengeNotifierProvider.notifier)
                                .respondToChallenge(c.id, accept: accept),
                          );
                        },
                        childCount: state.pendingInvites.length,
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Mes défis',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  if (state.myChallenges.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text(
                          'Aucun défi groupe.\nCrée-en un !',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => GroupChallengeCard(
                          challenge: state.myChallenges[i],
                          currentUserId: currentUserId,
                        ),
                        childCount: state.myChallenges.length,
                      ),
                    ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.createGroupChallenge),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau défi'),
        backgroundColor: const Color(0xFFF59E0B),
        foregroundColor: Colors.white,
      ),
    );
  }
}
