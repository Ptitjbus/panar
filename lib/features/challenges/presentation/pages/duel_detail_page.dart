import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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

    final subtitle = (duel.description?.trim().isNotEmpty ?? false)
        ? duel.description!.trim()
        : 'Pour avoir des grosses chosu';

    final isPendingInvite =
        duel.status == DuelStatus.pending && duel.challengedId == currentUserId;
    final canRun =
        duel.status == DuelStatus.accepted || duel.status == DuelStatus.active;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _TopHero(
              duel: duel,
              title:
                  duel.description?.split(' • ').first.trim().isNotEmpty == true
                  ? duel.description!.split(' • ').first.trim()
                  : 'Le Gwo Pied',
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _CenterActionCard(
                duel: duel,
                onTap: canRun
                    ? () => duel.timing == DuelTiming.live
                          ? context.push(
                              Routes.duelWaitingRoom.replaceFirst(
                                ':id',
                                duel.id,
                              ),
                            )
                          : context.push(Routes.runTracking)
                    : null,
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'A propos',
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _MetaChip(
                      text: '${_rewardFromDuel(duel)}💡',
                      background: const Color(0xFF909090),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetaChip(
                      text: duel.targetDistanceMeters != null
                          ? '${(duel.targetDistanceMeters! / 1000).toStringAsFixed(0)} Km'
                          : '4 Km',
                      background: const Color(0xFF909090),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetaChip(
                      text: 'J-${_remainingDays(duel)}',
                      background: Colors.black,
                      foreground: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Infos',
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (isPendingInvite) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
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
              ),
            ],
            if (!duel.isCompleted && !duel.isCancelled) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
            if (duel.isCompleted) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          duel.winnerId == currentUserId
                              ? 'Victoire !'
                              : 'Défi terminé',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TopHero extends StatelessWidget {
  final DuelEntity duel;
  final String title;

  const _TopHero({required this.duel, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 22),
      decoration: const BoxDecoration(
        color: Color(0xFFD9D9D9),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              duel.isSolo ? 'Solo' : 'Groupe',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.londrinaSolid(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterActionCard extends StatelessWidget {
  final DuelEntity duel;
  final VoidCallback? onTap;

  const _CenterActionCard({required this.duel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (duel.status == DuelStatus.active) {
      final progress = _duelProgress(duel);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFD1D1D1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progression du défi',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF909090),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: Text(
                      '${_rewardFromDuel(duel)}💡',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: progress,
                      backgroundColor: Colors.white,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 66,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.surfaceDark,
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          'Lancer le défi',
          style: GoogleFonts.inter(fontSize: 38, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;

  const _MetaChip({
    required this.text,
    required this.background,
    this.foreground = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 51,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.londrinaSolid(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: foreground,
        ),
      ),
    );
  }
}

int _rewardFromDuel(DuelEntity duel) {
  final fromTarget = duel.targetDistanceMeters != null
      ? (duel.targetDistanceMeters! / 20).round()
      : null;
  return math.max(50, fromTarget ?? 200);
}

int _remainingDays(DuelEntity duel) {
  if (duel.deadlineHours == null || duel.deadlineHours! <= 0) return 10;
  return math.max(1, (duel.deadlineHours! / 24).ceil());
}

double _duelProgress(DuelEntity duel) {
  if (duel.status == DuelStatus.completed) return 1;
  if (duel.challengerActivityId != null && duel.challengedActivityId != null) {
    return 0.95;
  }
  if (duel.challengerActivityId != null || duel.challengedActivityId != null) {
    return 0.52;
  }
  return 0.33;
}
