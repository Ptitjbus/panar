// lib/features/challenges/presentation/widgets/group_challenge_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
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

    final (chipLabel, chipBg, chipFg) = _chipStyle(isInvited);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isInvited
            ? null
            : () => context.push(
                Routes.groupChallengeDetail.replaceFirst(':id', challenge.id),
              ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusChip(label: chipLabel, bg: chipBg, fg: chipFg),
                  const Spacer(),
                  if (!isInvited)
                    const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                challenge.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${challenge.participants.length} participant${challenge.participants.length > 1 ? 's' : ''} · ${challenge.durationDays}j',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (challenge.targetDistanceMeters != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Progression équipe',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      '${challenge.teamDistanceLabel} / ${challenge.targetDistanceLabel}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: challenge.teamProgressRatio,
                    backgroundColor: AppColors.chipNeutralBg,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                  ),
                ),
              ],
              if (isInvited && onRespond != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => onRespond!(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Accepter', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onRespond!(false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Refuser', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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

  (String, Color, Color) _chipStyle(bool isInvited) {
    if (isInvited) return ('Invitation', AppColors.chipAccentBg, AppColors.accent);
    if (challenge.isActive) {
      return ('${challenge.daysRemaining}j restants', AppColors.chipAccentBg, AppColors.accent);
    }
    if (challenge.isCompleted) return ('Terminé', AppColors.chipNeutralBg, AppColors.textSecondary);
    return ('En attente', AppColors.chipNeutralBg, AppColors.textSecondary);
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _StatusChip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
