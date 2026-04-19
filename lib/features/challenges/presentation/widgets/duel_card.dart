// lib/features/challenges/presentation/widgets/duel_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../domain/entities/duel_entity.dart';

class DuelCard extends StatelessWidget {
  final DuelEntity duel;
  final String currentUserId;

  const DuelCard({super.key, required this.duel, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final otherProfile = duel.getOtherProfile(currentUserId);
    final otherName = otherProfile?.username ?? '…';

    final (chipLabel, chipBg, chipFg) = _chipStyle(currentUserId);
    final subtitleParts = <String>[
      duel.timing == DuelTiming.live ? 'Live' : 'Différé',
      if (duel.timing == DuelTiming.async && duel.deadlineHours != null)
        '${duel.deadlineHours}h',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(
          Routes.duelDetail.replaceFirst(':id', duel.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusChip(label: chipLabel, bg: chipBg, fg: chipFg),
                    const SizedBox(height: 6),
                    Text(
                      'vs @$otherName',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitleParts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitleParts.join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  (String, Color, Color) _chipStyle(String currentUserId) {
    switch (duel.status) {
      case DuelStatus.pending:
        return duel.challengerId == currentUserId
            ? ('En attente', AppColors.chipNeutralBg, AppColors.textSecondary)
            : ('Invitation reçue', AppColors.chipAccentBg, AppColors.accent);
      case DuelStatus.accepted:
        return ('Accepté', AppColors.chipAccentBg, AppColors.accent);
      case DuelStatus.active:
        return ('En cours', AppColors.accent, AppColors.surface);
      case DuelStatus.completed:
        return duel.winnerId == currentUserId
            ? ('Victoire ✓', AppColors.chipSuccessBg, AppColors.success)
            : ('Défaite', AppColors.chipDangerBg, AppColors.danger);
      case DuelStatus.rejected:
        return ('Refusé', AppColors.chipNeutralBg, AppColors.textSecondary);
      case DuelStatus.cancelled:
        return ('Annulé', AppColors.chipNeutralBg, AppColors.textSecondary);
    }
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
