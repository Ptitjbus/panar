import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/group_challenge_provider.dart';
import '../widgets/group_challenge_card.dart';

class _MonthlyTemplate {
  final String emoji;
  final String title;
  final String subtitle;
  final int durationDays;
  final double targetDistanceMeters;
  final String description;
  const _MonthlyTemplate({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.durationDays,
    required this.targetDistanceMeters,
    required this.description,
  });
}

const _kMonthlyTemplates = [
  _MonthlyTemplate(
    emoji: '🏆',
    title: 'Les 100 km du mois',
    subtitle: '100 km · 30 jours',
    durationDays: 30,
    targetDistanceMeters: 100000,
    description: 'Qui accumulera 100 km en premier ce mois-ci ?',
  ),
  _MonthlyTemplate(
    emoji: '⚡',
    title: 'Semi en équipe',
    subtitle: '21 km · 7 jours',
    durationDays: 7,
    targetDistanceMeters: 21097,
    description: 'Atteins la distance d\'un semi-marathon en une semaine.',
  ),
  _MonthlyTemplate(
    emoji: '🌅',
    title: 'Défi week-end',
    subtitle: '15 km · 3 jours',
    durationDays: 3,
    targetDistanceMeters: 15000,
    description: 'Le défi parfait pour un long week-end actif !',
  ),
];

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
                  // Monthly challenge templates
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Défis du mois',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _kMonthlyTemplates.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final t = _kMonthlyTemplates[i];
                          return GestureDetector(
                            onTap: () => context.push(
                              Routes.createGroupChallenge,
                              extra: {
                                'title': t.title,
                                'duration_days': t.durationDays,
                                'target_distance_meters': t.targetDistanceMeters,
                                'description': t.description,
                              },
                            ),
                            child: Container(
                              width: 170,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.emoji, style: const TextStyle(fontSize: 22)),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.title,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    t.subtitle,
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
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
