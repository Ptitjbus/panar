import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../challenges/domain/entities/duel_entity.dart';
import '../../../challenges/domain/entities/group_challenge_entity.dart';
import '../../../challenges/presentation/providers/duel_provider.dart';
import '../../../challenges/presentation/providers/group_challenge_provider.dart';
import '../../../friends/domain/entities/friendship_entity.dart';
import '../../../friends/presentation/providers/friends_provider.dart';

/// Provider for the total count of pending notifications.
final notificationCountProvider = Provider<int>((ref) {
  final friends = ref.watch(friendsNotifierProvider).receivedRequests.length;
  final duels = ref.watch(duelNotifierProvider).pendingInvites.length;
  final gcs = ref.watch(groupChallengeNotifierProvider).pendingInvites.length;
  return friends + duels + gcs;
});

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsState = ref.watch(friendsNotifierProvider);
    final duelState = ref.watch(duelNotifierProvider);
    final gcState = ref.watch(groupChallengeNotifierProvider);

    final requests = friendsState.receivedRequests;
    final duelInvites = duelState.pendingInvites;
    final gcInvites = gcState.pendingInvites;
    final isEmpty = requests.isEmpty && duelInvites.isEmpty && gcInvites.isEmpty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none_outlined,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Aucune notification',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        if (requests.isNotEmpty) ...[
                          _SectionHeader(
                            "Demandes d'amis",
                            requests.length,
                          ),
                          ...requests.map(
                            (f) => _FriendRequestTile(
                              friendship: f,
                              onDismiss: () =>
                                  Navigator.of(context).pop(),
                            ),
                          ),
                        ],
                        if (duelInvites.isNotEmpty) ...[
                          _SectionHeader('Défis reçus', duelInvites.length),
                          ...duelInvites.map(
                            (d) => _DuelInviteTile(
                              duel: d,
                              onTap: () {
                                Navigator.of(context).pop();
                                context.push(
                                  Routes.duelDetail
                                      .replaceFirst(':id', d.id),
                                );
                              },
                            ),
                          ),
                        ],
                        if (gcInvites.isNotEmpty) ...[
                          _SectionHeader(
                            'Quêtes collaboratives',
                            gcInvites.length,
                          ),
                          ...gcInvites.map(
                            (c) => _GroupChallengeInviteTile(
                              challenge: c,
                              onTap: () {
                                Navigator.of(context).pop();
                                context.push(
                                  Routes.groupChallengeDetail
                                      .replaceFirst(':id', c.id),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader(this.title, this.count);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendRequestTile extends ConsumerWidget {
  final FriendshipEntity friendship;
  final VoidCallback? onDismiss;

  const _FriendRequestTile({required this.friendship, this.onDismiss});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = friendship.requesterProfile;
    final username = profile?.username ?? 'Utilisateur';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceDark,
          child: Text(
            username[0].toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          username,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text("Demande d'ami"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionButton(
              icon: Icons.check,
              color: AppColors.success,
              onTap: () => ref
                  .read(friendsNotifierProvider.notifier)
                  .acceptRequest(friendship.id),
            ),
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.close,
              color: AppColors.danger,
              onTap: () => ref
                  .read(friendsNotifierProvider.notifier)
                  .rejectRequest(friendship.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _DuelInviteTile extends StatelessWidget {
  final DuelEntity duel;
  final VoidCallback onTap;

  const _DuelInviteTile({required this.duel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = duel.description?.split(' • ').first.trim().isNotEmpty == true
        ? duel.description!.split(' • ').first.trim()
        : 'Défi one-shot';
    final distance = duel.targetDistanceMeters != null
        ? '${(duel.targetDistanceMeters! / 1000).toStringAsFixed(0)} km'
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.surfaceDark,
          child: Icon(Icons.sports_score_outlined, size: 20),
        ),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(distance ?? 'Défi reçu'),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}

class _GroupChallengeInviteTile extends StatelessWidget {
  final GroupChallengeEntity challenge;
  final VoidCallback onTap;

  const _GroupChallengeInviteTile({
    required this.challenge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.surfaceDark,
          child: Icon(Icons.people_alt_outlined, size: 20),
        ),
        title: Text(
          challenge.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${challenge.targetDistanceLabel} · ${challenge.durationDays} jours',
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
