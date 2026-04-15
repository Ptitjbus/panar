import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/route_constants.dart';
import '../providers/duel_provider.dart';
import '../providers/group_challenge_provider.dart';
import '../widgets/challenge_mode_card.dart';

class ChallengesPage extends ConsumerWidget {
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duelState = ref.watch(duelNotifierProvider);
    final gcState = ref.watch(groupChallengeNotifierProvider);
    final pendingCount =
        duelState.pendingInvites.length + gcState.pendingInvites.length;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Défis',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Pending invitations banner
              if (pendingCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Text('📬', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$pendingCount invitation${pendingCount > 1 ? 's' : ''} en attente',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF92400E),
                              ),
                            ),
                            const Text(
                              'Réponds avant expiration',
                              style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Duel card
              ChallengeModeCard(
                emoji: '⚔️',
                title: 'Duel',
                subtitle: 'Affronte un ami sur une course · live ou différé',
                badges: const ['1 vs 1', '1 course'],
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => context.push(Routes.duels),
              ),
              const SizedBox(height: 16),

              // Groupe card
              ChallengeModeCard(
                emoji: '🏆',
                title: 'Défi groupe',
                subtitle: 'Cumule des km avec tes amis sur une période',
                badges: const ['2–10 joueurs', '3 / 7 / 30 jours'],
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => context.push(Routes.groupChallenges),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
