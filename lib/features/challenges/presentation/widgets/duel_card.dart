import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    Color borderColor;
    String statusLabel;
    switch (duel.status) {
      case DuelStatus.pending:
        borderColor = Colors.orange;
        statusLabel = duel.challengerId == currentUserId
            ? 'En attente · ${duel.timing == DuelTiming.live ? 'Live' : 'Différé'}'
            : '⚔️ Invitation reçue';
      case DuelStatus.accepted:
      case DuelStatus.active:
        borderColor = colorScheme.primary;
        statusLabel = 'En cours · ${duel.timing == DuelTiming.live ? 'Live' : 'Différé'}';
      case DuelStatus.completed:
        borderColor = duel.winnerId == currentUserId ? Colors.green : Colors.grey;
        statusLabel = duel.winnerId == currentUserId ? '✓ Victoire' : '✗ Défaite';
      case DuelStatus.rejected:
        borderColor = Colors.grey;
        statusLabel = 'Refusé';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(
          Routes.duelDetail.replaceFirst(':id', duel.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: borderColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'vs @$otherName',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (duel.timing == DuelTiming.async && duel.deadlineHours != null)
                      Text(
                        'Délai : ${duel.deadlineHours}h',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
