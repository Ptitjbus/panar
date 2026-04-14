import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_constants.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../providers/run_history_provider.dart';
import '../providers/run_tracking_provider.dart';
import '../widgets/run_metric_card.dart';
import '../widgets/run_static_map_widget.dart';

class RunStatsPage extends ConsumerWidget {
  final String activityId;

  const RunStatsPage({super.key, required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(runActivityDetailProvider(activityId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Résumé de la course'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(runTrackingProvider.notifier).resetRun();
            context.go(Routes.home);
          },
        ),
      ),
      body: detailAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Erreur lors du chargement',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.invalidate(runActivityDetailProvider(activityId)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (detail) {
          final activity = detail.activity;
          final points = detail.points;

          final dateStr = _formatDate(activity.startedAt);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Carte de tracé
                RunStaticMapWidget(points: points),

                const SizedBox(height: 24),

                // Stats
                Row(
                  children: [
                    Expanded(
                      child: RunMetricCard(
                        label: 'DISTANCE',
                        value: activity.formattedDistance.replaceAll(' km', ''),
                        unit: 'km',
                      ),
                    ),
                    Expanded(
                      child: RunMetricCard(
                        label: 'DURÉE',
                        value: activity.formattedDuration,
                        unit: 'mm:ss',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RunMetricCard(
                        label: 'ALLURE',
                        value: activity.formattedPace.replaceAll(' /km', ''),
                        unit: '/km',
                      ),
                    ),
                    Expanded(
                      child: RunMetricCard(
                        label: 'DATE',
                        value: dateStr,
                        unit: '',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                CustomButton(
                  text: "Retour à l'accueil",
                  onPressed: () {
                    ref.read(runTrackingProvider.notifier).resetRun();
                    context.go(Routes.home);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      '',
      'jan.',
      'fév.',
      'mar.',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sep.',
      'oct.',
      'nov.',
      'déc.',
    ];
    return '${date.day} ${months[date.month]}';
  }
}
