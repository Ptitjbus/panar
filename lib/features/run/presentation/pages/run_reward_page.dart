import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_constants.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../challenges/domain/entities/duel_entity.dart';
import '../../../challenges/presentation/providers/duel_provider.dart';
import '../../../challenges/presentation/providers/group_challenge_provider.dart';
import '../providers/run_tracking_provider.dart';
import '../widgets/run_metric_card.dart';
import '../widgets/treasure_chest_widget.dart';

class RunRewardPage extends ConsumerStatefulWidget {
  final String? activityId;

  const RunRewardPage({super.key, this.activityId});

  @override
  ConsumerState<RunRewardPage> createState() => _RunRewardPageState();
}

class _RunRewardPageState extends ConsumerState<RunRewardPage> {
  bool _chestOpened = false;

  @override
  void initState() {
    super.initState();
    if (widget.activityId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _autoLinkActivity(widget.activityId!);
      });
    }
  }

  Future<void> _autoLinkActivity(String activityId) async {
    // Link to active duel if any
    final duelState = ref.read(duelNotifierProvider);
    final activeDuel = duelState.myDuels
        .where((d) => d.isActive || d.status == DuelStatus.accepted)
        .firstOrNull;
    if (activeDuel != null) {
      await ref
          .read(duelNotifierProvider.notifier)
          .linkActivityToDuel(activeDuel.id, activityId);
    }

    // Add distance to active group challenges
    final gcState = ref.read(groupChallengeNotifierProvider);
    final distanceMeters = ref.read(runTrackingProvider).distanceMeters;
    for (final challenge in gcState.myChallenges.where((c) => c.isActive)) {
      await ref
          .read(groupChallengeNotifierProvider.notifier)
          .addRunDistance(challenge.id, distanceMeters);
    }
  }

  void _openChest() {
    if (_chestOpened) return;
    setState(() => _chestOpened = true);
  }

  @override
  Widget build(BuildContext context) {
    final runState = ref.watch(runTrackingProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Titre
              Text(
                'Course terminée !',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Voici vos statistiques',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 28),

              // Métriques
              Row(
                children: [
                  Expanded(
                    child: RunMetricCard(
                      label: 'DISTANCE',
                      value: runState.formattedDistance,
                      unit: 'km',
                    ),
                  ),
                  Expanded(
                    child: RunMetricCard(
                      label: 'DURÉE',
                      value: runState.formattedDuration,
                      unit: 'mm:ss',
                    ),
                  ),
                  Expanded(
                    child: RunMetricCard(
                      label: 'ALLURE',
                      value: runState.formattedPace,
                      unit: '/km',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Section coffre
              Text(
                _chestOpened ? 'Vous avez gagné !' : 'Ouvrez votre récompense',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Coffre animé
              Center(
                child: GestureDetector(
                  onTap: _openChest,
                  child: TreasureChestWidget(
                    isOpen: _chestOpened,
                    petons: runState.petonEarned,
                  ),
                ),
              ),

              if (!_chestOpened) ...[
                const SizedBox(height: 12),
                Text(
                  'Appuyez sur le coffre pour l\'ouvrir',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              if (_chestOpened && runState.newPetonsBalance != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Solde total : ${runState.newPetonsBalance} petons',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 36),

              if (activityId != null)
                CustomButton(
                  text: 'Voir mes stats détaillées',
                  onPressed: () => context.go(
                    Routes.runStats,
                    extra: {'activityId': widget.activityId},
                  ),
                ),

              const SizedBox(height: 12),

              CustomButton(
                text: "Retour à l'accueil",
                isOutlined: true,
                onPressed: () {
                  ref.read(runTrackingProvider.notifier).resetRun();
                  context.go(Routes.home);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? get activityId => widget.activityId;
}
