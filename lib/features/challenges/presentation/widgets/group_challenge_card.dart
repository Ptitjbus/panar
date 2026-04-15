import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/route_constants.dart';
import '../../domain/entities/group_challenge_entity.dart';
import '../../domain/entities/group_challenge_participant_entity.dart';

class GroupChallengeCard extends StatelessWidget {
  final GroupChallengeEntity challenge;
  final String currentUserId;
  final void Function(bool accept)? onRespond;

  const GroupChallengeCard({
    super.key,
    required this.challenge,
    required this.currentUserId,
    this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    final myParticipation = challenge.participants
        .where((p) => p.userId == currentUserId)
        .firstOrNull;
    final isInvited = myParticipation?.status == ParticipantStatus.invited;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isInvited
              ? const Color(0xFF6C63FF)
              : challenge.isActive
                  ? const Color(0xFFF59E0B)
                  : Colors.grey.shade300,
          width: isInvited || challenge.isActive ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isInvited
            ? null
            : () => context.push(
                Routes.groupChallengeDetail.replaceFirst(':id', challenge.id),
              ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isInvited
                              ? 'Invitation reçue'
                              : challenge.isActive
                                  ? '${challenge.daysRemaining}j restants'
                                  : challenge.isCompleted
                                      ? 'Terminé'
                                      : 'En attente',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isInvited
                                ? const Color(0xFF6C63FF)
                                : challenge.isActive
                                    ? const Color(0xFFF59E0B)
                                    : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          challenge.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          '${challenge.participants.length} participant${challenge.participants.length > 1 ? 's' : ''} · ${challenge.durationDays}j',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (!isInvited) const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              if (challenge.isActive) ...[
                const SizedBox(height: 10),
                ...challenge.sortedLeaderboard.take(3).toList().asMap().entries.map((e) {
                  final medals = ['🥇', '🥈', '🥉'];
                  final p = e.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text(medals[e.key], style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          '@${p.profile?.username ?? p.userId.substring(0, 6)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const Spacer(),
                        Text(
                          p.formattedDistance,
                          style: TextStyle(
                            fontWeight: p.userId == currentUserId ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              if (isInvited && onRespond != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => onRespond!(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Accepter', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onRespond!(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Refuser', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
