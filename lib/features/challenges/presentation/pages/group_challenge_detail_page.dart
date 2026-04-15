import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/group_challenge_participant_entity.dart';
import '../providers/group_challenge_provider.dart';

class GroupChallengeDetailPage extends ConsumerWidget {
  final String challengeId;
  const GroupChallengeDetailPage({super.key, required this.challengeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupChallengeNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';
    final challenge = state.myChallenges
        .where((c) => c.id == challengeId)
        .firstOrNull;

    if (challenge == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Défi')),
        body: const Center(child: Text('Défi introuvable')),
      );
    }

    final pendingParticipants = challenge.participants
        .where((p) => p.status == ParticipantStatus.invited)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(challenge.title)),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(groupChallengeNotifierProvider.notifier).loadChallenges(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Status row
            Row(
              children: [
                Chip(
                  label: Text(
                    challenge.isPending
                        ? 'En attente'
                        : challenge.isActive
                            ? 'En cours'
                            : 'Terminé',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: challenge.isPending
                      ? Colors.orange
                      : challenge.isActive
                          ? const Color(0xFFF59E0B)
                          : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text('${challenge.durationDays} jours', style: const TextStyle(color: Colors.grey)),
                if (challenge.isActive) ...[
                  const SizedBox(width: 8),
                  Text('· ${challenge.daysRemaining}j restants', style: const TextStyle(color: Colors.grey)),
                ],
              ],
            ),

            // Force-start button (creator only, some rejected)
            if (challenge.creatorId == currentUserId && challenge.canForceStart) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref
                    .read(groupChallengeNotifierProvider.notifier)
                    .forceStart(challengeId),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Lancer maintenant'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
              ),
            ],

            const SizedBox(height: 24),
            const Text('Classement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 12),

            if (challenge.participants.isEmpty)
              const Text('Aucun participant pour le moment.', style: TextStyle(color: Colors.grey))
            else
              ...challenge.sortedLeaderboard.toList().asMap().entries.map((entry) {
                final rank = entry.key;
                final p = entry.value;
                final medals = ['🥇', '🥈', '🥉'];
                final medalEmoji = rank < 3 ? medals[rank] : '${rank + 1}.';
                final isMe = p.userId == currentUserId;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0xFFFEF3C7)
                        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: isMe
                        ? Border.all(color: const Color(0xFFF59E0B), width: 1.5)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Text(medalEmoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '@${p.profile?.username ?? p.userId.substring(0, 6)}${isMe ? ' (moi)' : ''}',
                          style: TextStyle(
                            fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      Text(
                        p.formattedDistance,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isMe ? const Color(0xFFB45309) : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }),

            if (pendingParticipants.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'En attente de réponse',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ...pendingParticipants.map((p) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text('@${p.profile?.username ?? p.userId.substring(0, 6)}'),
                trailing: const Text('En attente…', style: TextStyle(color: Colors.grey, fontSize: 12)),
              )),
            ],
          ],
        ),
      ),
    );
  }
}
