import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../shared/widgets/panar_breadcrumb.dart';
import '../../../../shared/widgets/panar_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/group_challenge_entity.dart';
import '../../domain/entities/group_challenge_participant_entity.dart';
import '../providers/group_challenge_provider.dart';

class GroupChallengeDetailPage extends ConsumerStatefulWidget {
  final String challengeId;

  const GroupChallengeDetailPage({super.key, required this.challengeId});

  @override
  ConsumerState<GroupChallengeDetailPage> createState() =>
      _GroupChallengeDetailPageState();
}

class _GroupChallengeDetailPageState
    extends ConsumerState<GroupChallengeDetailPage> {
  bool _rewardOpened = false;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la quête ?'),
        content: const Text(
          'La quête sera supprimée pour tous les participants. Cette action est irréversible.',
        ),
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
          .deleteChallenge(widget.challengeId);
      if (success && context.mounted) {
        context.pop();
      }
    }
  }

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter la quête ?'),
        content: const Text('Tu ne pourras plus participer à cette quête.'),
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
          .leaveChallenge(widget.challengeId);
      if (success && context.mounted) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupChallengeNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';

    final challenge = [
      ...state.myChallenges,
      ...state.pendingInvites,
    ].where((c) => c.id == widget.challengeId).firstOrNull;

    if (challenge == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(),
        body: const Center(child: Text('Quête introuvable')),
      );
    }

    final myParticipation = challenge.participants
        .where((p) => p.userId == currentUserId)
        .firstOrNull;
    final isCreator = challenge.creatorId == currentUserId;
    final isInvited = myParticipation?.status == ParticipantStatus.invited;
    final canLeave =
        !isCreator &&
        (myParticipation?.status == ParticipantStatus.accepted ||
            myParticipation?.status == ParticipantStatus.invited);

    if (challenge.isCompleted || _rewardOpened) {
      return _QuestRewardView(
        challenge: challenge,
        rewardOpened: _rewardOpened,
        onOpenReward: () => setState(() => _rewardOpened = true),
      );
    }

    if (challenge.isActive) {
      return _QuestProgressView(
        challenge: challenge,
        currentUserId: currentUserId,
        onShowReward: () => setState(() => _rewardOpened = true),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quête collaborative'),
        actions: [
          if (isCreator)
            IconButton(
              onPressed: () => _confirmDelete(context, ref),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const PanarBreadcrumb('Collaboration'),
            const SizedBox(height: 8),
            Text(
              challenge.title,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 4),
            Text(
              challenge.description ?? 'Petit pas par petit pas',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _QuestStatCard(challenge: challenge),
            const SizedBox(height: 16),
            Text(
              'Participants',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ...challenge.participants.map(
              (participant) => _ParticipantTile(
                participant: participant,
                isCurrentUser: participant.userId == currentUserId,
              ),
            ),
            const SizedBox(height: 24),
            if (isInvited)
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => ref
                          .read(groupChallengeNotifierProvider.notifier)
                          .respondToChallenge(challenge.id, accept: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Accepter'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ref
                          .read(groupChallengeNotifierProvider.notifier)
                          .respondToChallenge(challenge.id, accept: false),
                      child: const Text('Refuser'),
                    ),
                  ),
                ],
              ),
            if (isCreator && challenge.canForceStart) ...[
              PanarButton.black(
                label: 'Lancer la quête',
                onPressed: () => ref
                    .read(groupChallengeNotifierProvider.notifier)
                    .forceStart(challenge.id),
              ),
              const SizedBox(height: 10),
            ],
            if (canLeave)
              OutlinedButton(
                onPressed: () => _confirmLeave(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
                child: const Text('Quitter la quête'),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuestProgressView extends ConsumerWidget {
  final GroupChallengeEntity challenge;
  final String currentUserId;
  final VoidCallback onShowReward;

  const _QuestProgressView({
    required this.challenge,
    required this.currentUserId,
    required this.onShowReward,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kmDone = (challenge.teamDistanceMeters / 1000).round();
    final targetKm = challenge.targetDistanceMeters != null
        ? (challenge.targetDistanceMeters! / 1000).round()
        : null;
    final acceptedParticipants = challenge.participants
        .where((p) => p.status == ParticipantStatus.accepted)
        .toList();
    final perUserTargetKm = targetKm != null && acceptedParticipants.isNotEmpty
        ? targetKm / acceptedParticipants.length
        : null;

    final partner = challenge.activeParticipants
        .where((p) => p.userId != currentUserId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  const PanarBreadcrumb('Collaboration'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 0),
              child: Text(
                'A deux on va plus loin !',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Text(
                challenge.description ?? 'Petit pas par petit pas',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const _FootstepsBackground(),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🤜🤛', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 8),
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.surfaceDark,
                        child: Text(
                          '$kmDone',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        targetKm == null
                            ? '$kmDone km cumulés'
                            : '$kmDone / $targetKm km',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: challenge.teamProgressRatio,
                          borderRadius: BorderRadius.circular(999),
                          backgroundColor: AppColors.surfaceDark,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (acceptedParticipants.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progression des participants',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...acceptedParticipants.map((participant) {
                        final username =
                            participant.profile?.username ??
                            participant.userId.substring(0, 6);
                        final userKm = participant.totalDistanceMeters / 1000;
                        final ratio =
                            perUserTargetKm == null || perUserTargetKm <= 0
                            ? 0.0
                            : (userKm / perUserTargetKm)
                                  .clamp(0.0, 1.0)
                                  .toDouble();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      participant.userId == currentUserId
                                          ? '$username (toi)'
                                          : username,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${userKm.toStringAsFixed(2)} km',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                minHeight: 8,
                                value: ratio,
                                borderRadius: BorderRadius.circular(999),
                                backgroundColor: AppColors.surfaceDark,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (partner != null)
                    OutlinedButton.icon(
                      onPressed: () => context.push(
                        Routes.createDuel,
                        extra: {'friendId': partner.userId},
                      ),
                      icon: const Icon(Icons.people_alt_outlined),
                      label: const Text('Course en direct (salle d\'attente)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 58,
                    child: FilledButton(
                      onPressed: challenge.teamProgressRatio >= 1
                          ? onShowReward
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.surfaceDark,
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        challenge.teamProgressRatio >= 1
                            ? 'Récompenses'
                            : 'Objectif en cours',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestRewardView extends StatelessWidget {
  final GroupChallengeEntity challenge;
  final bool rewardOpened;
  final VoidCallback onOpenReward;

  const _QuestRewardView({
    required this.challenge,
    required this.rewardOpened,
    required this.onOpenReward,
  });

  @override
  Widget build(BuildContext context) {
    final gained =
        (challenge.targetDistanceMeters != null
                ? challenge.targetDistanceMeters! / 200
                : challenge.teamDistanceMeters / 200)
            .round();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: PanarBreadcrumb('Récompenses'),
              ),
            ),
            const SizedBox(height: 8),
            if (!rewardOpened) ...[
              const Text(
                'BRAVO\nA VOUS 2',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 64,
                  height: 0.9,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Découvrez vos récompenses',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const Spacer(),
              const Text('📦', style: TextStyle(fontSize: 170)),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 80),
                child: SizedBox(
                  height: 60,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onOpenReward,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.surfaceDark,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Ouvrir',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Text(
                '$gained',
                style: const TextStyle(
                  fontSize: 76,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ampoules gagnées',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const Spacer(),
              const Text('💡', style: TextStyle(fontSize: 170)),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 80),
                child: SizedBox(
                  height: 60,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () =>
                        context.go(Routes.home, extra: {'index': 1}),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.surfaceDark,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Récupérer',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _FootstepsBackground extends StatelessWidget {
  const _FootstepsBackground();

  @override
  Widget build(BuildContext context) {
    final steps = <_FootstepData>[
      const _FootstepData(left: 0.30, top: 0.15, angle: -0.55),
      const _FootstepData(left: 0.58, top: 0.23, angle: 0.45),
      const _FootstepData(left: 0.43, top: 0.43, angle: -0.4),
      const _FootstepData(left: 0.61, top: 0.53, angle: 0.52),
      const _FootstepData(left: 0.36, top: 0.66, angle: -0.55),
      const _FootstepData(left: 0.54, top: 0.79, angle: 0.50),
    ];

    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: steps
            .map(
              (step) => Positioned(
                left: constraints.maxWidth * step.left,
                top: constraints.maxHeight * step.top,
                child: Transform.rotate(
                  angle: step.angle,
                  child: const Icon(
                    Icons.directions_walk_rounded,
                    color: Color(0xFFD3D3D3),
                    size: 56,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _FootstepData {
  final double left;
  final double top;
  final double angle;

  const _FootstepData({
    required this.left,
    required this.top,
    required this.angle,
  });
}

class _QuestStatCard extends StatelessWidget {
  final GroupChallengeEntity challenge;

  const _QuestStatCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Distance cumulée'),
              Text(
                '${challenge.teamDistanceLabel} / ${challenge.targetDistanceLabel}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            minHeight: 8,
            value: challenge.teamProgressRatio,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: AppColors.surfaceDark,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final GroupChallengeParticipantEntity participant;
  final bool isCurrentUser;

  const _ParticipantTile({
    required this.participant,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final username =
        participant.profile?.username ?? participant.userId.substring(0, 6);
    final status = switch (participant.status) {
      ParticipantStatus.accepted => 'Participe',
      ParticipantStatus.invited => 'Invité',
      ParticipantStatus.rejected => 'Refusé',
      ParticipantStatus.left => 'A quitté',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppColors.textPrimary : AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isCurrentUser ? Colors.white24 : Colors.black12,
            child: Text(
              username[0].toUpperCase(),
              style: TextStyle(
                color: isCurrentUser ? Colors.white : Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser ? '$username (toi)' : username,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isCurrentUser ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$status · ${participant.formattedDistance}',
                  style: TextStyle(
                    color: isCurrentUser
                        ? Colors.white70
                        : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
