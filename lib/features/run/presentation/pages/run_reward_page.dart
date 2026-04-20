import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/experiments/app_experiments.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../shared/widgets/panar_breadcrumb.dart';
import '../../../../shared/widgets/panar_button.dart';
import '../../../challenges/domain/entities/duel_entity.dart';
import '../../../challenges/presentation/providers/duel_provider.dart';
import '../../../challenges/presentation/providers/group_challenge_provider.dart';
import '../providers/run_tracking_provider.dart';
import '../widgets/treasure_chest_widget.dart';

class RunRewardPage extends ConsumerStatefulWidget {
  final String? activityId;

  const RunRewardPage({super.key, this.activityId});

  @override
  ConsumerState<RunRewardPage> createState() => _RunRewardPageState();
}

class _RunRewardPageState extends ConsumerState<RunRewardPage> {
  bool _chestOpened = false;

  String get _statsVariant => ref.read(
    trackedExperimentVariantProvider(
      AppExperimentKeys.statsConsultationVariant,
    ),
  );

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
    final duelState = ref.read(duelNotifierProvider);
    final activeDuel = duelState.myDuels
        .where((d) => d.isActive || d.status == DuelStatus.accepted)
        .firstOrNull;
    if (activeDuel != null) {
      await ref
          .read(duelNotifierProvider.notifier)
          .linkActivityToDuel(activeDuel.id, activityId);
    }

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
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logFunnelStep(
            funnel: 'run_stats',
            step: 'reward_chest_opened',
            source: 'run_reward_page',
            variant: _statsVariant,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final runState = ref.watch(runTrackingProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: const PanarBreadcrumb('Récompenses'),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Big celebration title
                    Text(
                      _chestOpened ? 'OUVERT !\nBRAVO !' : 'BRAVO\nCHAMPION',
                      style: theme.textTheme.displayMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _chestOpened
                          ? 'Voici tes récompenses'
                          : 'Découvre tes récompenses',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Chest widget
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
                      const SizedBox(height: 16),
                      Text(
                        'Appuie sur la boîte pour ouvrir',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],

                    if (_chestOpened && runState.newPetonsBalance != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Solde total : ${runState.newPetonsBalance} 💡',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 48),

                    if (widget.activityId != null)
                      PanarButton(
                        label: 'Voir mes stats',
                        onPressed: () {
                          unawaited(
                            ref
                                .read(analyticsServiceProvider)
                                .logFunnelStep(
                                  funnel: 'run_stats',
                                  step: 'view_stats_tapped',
                                  source: 'run_reward_page',
                                  variant: _statsVariant,
                                ),
                          );
                          context.go(
                            Routes.runStats,
                            extra: {'activityId': widget.activityId},
                          );
                        },
                      ),

                    if (widget.activityId != null) const SizedBox(height: 12),

                    PanarButton.black(
                      label: "Retour à l'accueil",
                      onPressed: () {
                        ref.read(runTrackingProvider.notifier).resetRun();
                        context.go(Routes.home);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
