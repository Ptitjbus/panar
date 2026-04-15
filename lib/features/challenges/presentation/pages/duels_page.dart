import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/duel_provider.dart';
import '../widgets/duel_card.dart';

class DuelsPage extends ConsumerWidget {
  const DuelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(duelNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duels ⚔️'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nouveau duel',
            onPressed: () => context.push(Routes.createDuel),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(duelNotifierProvider.notifier).loadDuels(),
        child: state.isLoading && state.myDuels.isEmpty && state.pendingInvites.isEmpty
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
                        (_, i) => DuelCard(
                          duel: state.pendingInvites[i],
                          currentUserId: currentUserId,
                        ),
                        childCount: state.pendingInvites.length,
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Mes duels',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  if (state.myDuels.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text(
                          'Aucun duel pour le moment.\nDéfie un ami !',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => DuelCard(
                          duel: state.myDuels[i],
                          currentUserId: currentUserId,
                        ),
                        childCount: state.myDuels.length,
                      ),
                    ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.createDuel),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau duel'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
      ),
    );
  }
}
