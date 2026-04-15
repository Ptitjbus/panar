import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/duel_entity.dart';
import '../providers/duel_provider.dart';

class DuelDetailPage extends ConsumerWidget {
  final String duelId;
  const DuelDetailPage({super.key, required this.duelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(duelNotifierProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';

    final duel = [
      ...state.myDuels,
      ...state.pendingInvites,
    ].where((d) => d.id == duelId).firstOrNull;

    if (duel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Duel')),
        body: const Center(child: Text('Duel introuvable')),
      );
    }

    final otherProfile = duel.getOtherProfile(currentUserId);
    final otherName = otherProfile?.username ?? '…';

    return Scaffold(
      appBar: AppBar(title: Text('vs @$otherName')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusChip(duel: duel, currentUserId: currentUserId),
            const SizedBox(height: 20),
            Text(
              'Mode : ${duel.timing == DuelTiming.live ? '⚡ Live' : '🕐 Différé'}',
              style: const TextStyle(fontSize: 15),
            ),
            if (duel.timing == DuelTiming.async && duel.deadlineHours != null)
              Text('Délai : ${duel.deadlineHours}h', style: const TextStyle(color: Colors.grey)),
            if (duel.targetDistanceMeters != null) ...[
              const SizedBox(height: 8),
              Text(
                'Distance cible : ${(duel.targetDistanceMeters! / 1000).toStringAsFixed(1)} km',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF6C63FF)),
              ),
            ],
            if (duel.description != null && duel.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(duel.description!, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 24),
            if (duel.isPending && duel.challengedId == currentUserId) ...[
              const Text(
                'Tu as reçu ce défi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => ref
                          .read(duelNotifierProvider.notifier)
                          .respondToDuel(duelId, accept: true),
                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Accepter'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ref
                          .read(duelNotifierProvider.notifier)
                          .respondToDuel(duelId, accept: false),
                      child: const Text('Refuser'),
                    ),
                  ),
                ],
              ),
            ],
            if (duel.status == DuelStatus.accepted || duel.status == DuelStatus.active) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: () {
                    context.push(Routes.runTracking);
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  label: const Text(
                    'Démarrer le duel en direct',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
            if (duel.isCompleted) ...[
              const Divider(height: 32),
              const Text('Résultat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (duel.winnerId != null)
                Text(
                  duel.winnerId == currentUserId ? '🥇 Tu as gagné !' : '🥈 Tu as perdu',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: duel.winnerId == currentUserId ? Colors.green : Colors.grey,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final DuelEntity duel;
  final String currentUserId;
  const _StatusChip({required this.duel, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (duel.status) {
      case DuelStatus.pending:   label = 'En attente';  color = Colors.orange;
      case DuelStatus.accepted:  label = 'Accepté';     color = Colors.blue;
      case DuelStatus.active:    label = 'En cours';    color = const Color(0xFF6C63FF);
      case DuelStatus.completed: label = 'Terminé';     color = Colors.green;
      case DuelStatus.rejected:  label = 'Refusé';      color = Colors.grey;
    }
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
    );
  }
}
