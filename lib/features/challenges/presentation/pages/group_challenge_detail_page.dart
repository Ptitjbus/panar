// lib/features/challenges/presentation/pages/group_challenge_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/group_challenge_entity.dart';
import '../../domain/entities/group_challenge_participant_entity.dart';
import '../providers/group_challenge_provider.dart';

class GroupChallengeDetailPage extends ConsumerWidget {
  final String challengeId;
  const GroupChallengeDetailPage({super.key, required this.challengeId});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le défi ?'),
        content: const Text('Le défi sera supprimé pour tous les participants. Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final success = await ref
          .read(groupChallengeNotifierProvider.notifier)
          .deleteChallenge(challengeId);
      if (success && context.mounted) context.pop();
    }
  }

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter le défi ?'),
        content: const Text('Tu ne pourras plus participer à ce défi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final success = await ref
          .read(groupChallengeNotifierProvider.notifier)
          .leaveChallenge(challengeId);
      if (success && context.mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupChallengeNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';
    final challenge = [...state.myChallenges, ...state.pendingInvites]
        .where((c) => c.id == challengeId)
        .firstOrNull;

    if (challenge == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.surface, title: const Text('Défi')),
        body: const Center(child: Text('Défi introuvable')),
      );
    }

    final pendingParticipants = challenge.participants
        .where((p) => p.status == ParticipantStatus.invited)
        .toList();

    final myParticipation = challenge.participants
        .where((p) => p.userId == currentUserId)
        .firstOrNull;

    final isCreator = challenge.creatorId == currentUserId;
    final canLeave = !isCreator &&
        (myParticipation?.status == ParticipantStatus.accepted ||
         myParticipation?.status == ParticipantStatus.invited);
    final canDelete = isCreator && !challenge.isCompleted;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(challenge.title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(groupChallengeNotifierProvider.notifier).loadChallenges(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info card
            _InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChallengeStatusChip(challenge: challenge),
                  const SizedBox(height: 12),
                  _InfoRow(icon: Icons.calendar_today_rounded, label: '${challenge.durationDays} jours'),
                  if (challenge.isActive)
                    _InfoRow(
                      icon: Icons.hourglass_bottom_rounded,
                      label: '${challenge.daysRemaining} jour${challenge.daysRemaining > 1 ? 's' : ''} restant${challenge.daysRemaining > 1 ? 's' : ''}',
                      highlight: true,
                    ),
                  if (challenge.targetDistanceMeters != null)
                    _InfoRow(
                      icon: Icons.straighten_rounded,
                      label: 'Objectif : ${(challenge.targetDistanceMeters! / 1000).toStringAsFixed(0)} km',
                      highlight: true,
                    ),
                  if (challenge.description != null && challenge.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      challenge.description!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Force-start
            if (isCreator && challenge.canForceStart) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => ref
                      .read(groupChallengeNotifierProvider.notifier)
                      .forceStart(challengeId),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Lancer maintenant', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],

            // Progression commune
            const SizedBox(height: 20),
            const Text(
              'Progression commune',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            _InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Distance cumulée',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      Text(
                        '${challenge.teamDistanceLabel} / ${challenge.targetDistanceLabel}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: challenge.teamProgressRatio,
                      backgroundColor: AppColors.chipNeutralBg,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Contributions',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),

            if (challenge.activeParticipants.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aucune contribution pour le moment.', style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              ...challenge.activeParticipants.map((p) {
                final isMe = p.userId == currentUserId;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFFF0F7FF) : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isMe ? AppColors.accent : AppColors.border,
                      width: isMe ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.chipNeutralBg,
                        child: Icon(Icons.person, size: 16, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '@${p.profile?.username ?? p.userId.substring(0, 6)}${isMe ? ' (moi)' : ''}',
                          style: TextStyle(
                            fontWeight: isMe ? FontWeight.w700 : FontWeight.normal,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        p.formattedDistance,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isMe ? AppColors.accent : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }),

            // Participants en attente
            if (pendingParticipants.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'En attente de réponse',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              ...pendingParticipants.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.chipNeutralBg,
                      child: Icon(Icons.person, color: AppColors.textSecondary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text('@${p.profile?.username ?? p.userId.substring(0, 6)}')),
                    const Text('En attente…', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              )),
            ],

            // Actions destructives
            const SizedBox(height: 28),
            if (canDelete)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _confirmDelete(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Supprimer le défi', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            if (canLeave)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _confirmLeave(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Quitter le défi', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  const _InfoRow({required this.icon, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: highlight ? AppColors.accent : AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: highlight ? AppColors.accent : AppColors.textPrimary,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeStatusChip extends StatelessWidget {
  final GroupChallengeEntity challenge;
  const _ChallengeStatusChip({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = challenge.isActive
        ? ('En cours', AppColors.accent, AppColors.surface)
        : challenge.isCompleted
            ? ('Terminé', AppColors.chipNeutralBg, AppColors.textSecondary)
            : ('En attente', AppColors.chipNeutralBg, AppColors.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
