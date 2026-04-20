import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/duel_entity.dart';
import '../providers/duel_provider.dart';

class DuelDetailPage extends ConsumerStatefulWidget {
  final String duelId;
  const DuelDetailPage({super.key, required this.duelId});

  @override
  ConsumerState<DuelDetailPage> createState() => _DuelDetailPageState();
}

class _DuelDetailPageState extends ConsumerState<DuelDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(duelNotifierProvider.notifier).loadDuels();
    });
  }

  Future<void> _confirmCancel(String duelId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler le défi ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Annuler le défi'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final success = await ref
          .read(duelNotifierProvider.notifier)
          .cancelDuel(duelId);
      if (success && mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(duelNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';

    final duel = [
      ...state.myDuels,
      ...state.pendingInvites,
    ].where((d) => d.id == widget.duelId).firstOrNull;

    if (duel == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text('Défi one-shot'),
        ),
        body: const Center(child: Text('Défi introuvable')),
      );
    }

    final otherProfile = duel.getOtherProfile(currentUserId);
    final otherName = otherProfile?.username ?? '…';
    final challengerName =
        duel.challengerProfile?.username ?? duel.challengerId.substring(0, 6);
    final challengedName =
        duel.challengedProfile?.username ?? duel.challengedId.substring(0, 6);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'vs @$otherName',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DuelStatusChip(duel: duel, currentUserId: currentUserId),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: duel.timing == DuelTiming.live
                      ? Icons.bolt_rounded
                      : Icons.schedule_rounded,
                  label: duel.timing == DuelTiming.live ? 'Live' : 'Différé',
                ),
                if (duel.timing == DuelTiming.async &&
                    duel.deadlineHours != null)
                  _InfoRow(
                    icon: Icons.timer_outlined,
                    label: 'Délai : ${duel.deadlineHours}h',
                  ),
                if (duel.targetDistanceMeters != null)
                  _InfoRow(
                    icon: Icons.straighten_rounded,
                    label:
                        '${(duel.targetDistanceMeters! / 1000).toStringAsFixed(1)} km',
                    highlight: true,
                  ),
                if (duel.description != null &&
                    duel.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    duel.description!,
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
          const SizedBox(height: 12),

          if (duel.isPending && duel.challengedId == currentUserId)
            _InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tu as reçu ce défi one-shot',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () => ref
                              .read(duelNotifierProvider.notifier)
                              .respondToDuel(widget.duelId, accept: true),
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
                              .read(duelNotifierProvider.notifier)
                              .respondToDuel(widget.duelId, accept: false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Refuser',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          if ((duel.status == DuelStatus.accepted ||
                  duel.status == DuelStatus.active) &&
              duel.timing == DuelTiming.live) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: () => context.push(
                  Routes.duelWaitingRoom.replaceFirst(':id', duel.id),
                ),
                icon: const Icon(Icons.people_rounded, size: 22),
                label: const Text(
                  "Rejoindre la salle d'attente",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],

          if ((duel.status == DuelStatus.accepted ||
                  duel.status == DuelStatus.active) &&
              duel.timing == DuelTiming.async) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: () => context.push(Routes.runTracking),
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: const Text(
                  'Démarrer ma course',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],

          if (duel.isCompleted) ...[
            const SizedBox(height: 12),
            _InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Résultat',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  if (duel.winnerId != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          duel.winnerId == currentUserId
                              ? '🥇 Victoire !'
                              : '🥈 Défaite',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: duel.winnerId == currentUserId
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ResultRow(
                          username: challengerName,
                          isWinner: duel.winnerId == duel.challengerId,
                        ),
                        const SizedBox(height: 6),
                        _ResultRow(
                          username: challengedName,
                          isWinner: duel.winnerId == duel.challengedId,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],

          if (duel.status != DuelStatus.completed &&
              duel.status != DuelStatus.cancelled) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _confirmCancel(duel.id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Annuler le défi',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
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
  const _InfoRow({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: highlight ? AppColors.accent : AppColors.textSecondary,
          ),
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

class _DuelStatusChip extends StatelessWidget {
  final DuelEntity duel;
  final String currentUserId;
  const _DuelStatusChip({required this.duel, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (duel.status) {
      DuelStatus.pending => (
        'En attente',
        AppColors.chipNeutralBg,
        AppColors.textSecondary,
      ),
      DuelStatus.accepted => (
        'Accepté',
        AppColors.chipAccentBg,
        AppColors.accent,
      ),
      DuelStatus.active => ('En cours', AppColors.accent, AppColors.surface),
      DuelStatus.completed =>
        duel.winnerId == currentUserId
            ? ('Victoire ✓', AppColors.chipSuccessBg, AppColors.success)
            : ('Défaite', AppColors.chipDangerBg, AppColors.danger),
      DuelStatus.rejected => (
        'Refusé',
        AppColors.chipNeutralBg,
        AppColors.textSecondary,
      ),
      DuelStatus.cancelled => (
        'Annulé',
        AppColors.chipNeutralBg,
        AppColors.textSecondary,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String username;
  final bool isWinner;
  const _ResultRow({required this.username, required this.isWinner});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isWinner ? Icons.emoji_events_rounded : Icons.flag_outlined,
          size: 16,
          color: isWinner ? AppColors.success : AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '@$username',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          isWinner ? 'Gagnant' : 'Perdant',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isWinner ? AppColors.success : AppColors.danger,
          ),
        ),
      ],
    );
  }
}
